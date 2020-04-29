type transferParam is address * (address * nat);

type initiateParam is record
  hashedSecret: bytes;
  participant: address;
  refundTime: timestamp;
  transferEntry: contract(transferParam);
  totalAmount: nat;
  payoffAmount: nat;
end

type parameter is 
| Initiate of initiateParam
| Redeem of bytes
| Refund of bytes

type swapState is record
  initiator: address;
  participant: address;
  refundTime: timestamp;
  tokenAddress: address;
  totalAmount: nat;
  payoffAmount: nat;
end

type storage is big_map(bytes, swapState);

function getSwapState(const hashedSecret: bytes; const s: storage) : swapState is
  case s[hashedSecret] of
    | Some(state) -> state
    | None -> (failwith("Not initiated") : swapState)
  end; attributes ["inline"];

function getTransferEntry(const tokenAddress: address) : contract(transferParam) is
  case (Tezos.get_contract_opt(tokenAddress) : option(contract(transferParam))) of
    | Some(entry) -> entry
    | None -> (failwith("Transfer is not supported") : contract(transferParam))
  end; attributes ["inline"];

function transfer(const transferEntry: contract(transferParam); 
                  const src: address;
                  const dst: address; 
                  const value: nat) : operation is
  block {
    const params: transferParam = (src, (dst, value));
    const op: operation = Tezos.transaction(params, 0tz, transferEntry);
  } with op; attributes ["inline"];

function thirdPartyRedeem(const transferEntry: contract(transferParam); const payoffAmount: nat) : list(operation) is
  block {
    const hasPayoff: bool = payoffAmount > 0n;
  } with case hasPayoff of
    | True -> list[transfer(transferEntry, Tezos.self_address, Tezos.source, payoffAmount)]
    | False -> (nil : list(operation))
  end; attributes ["inline"];

function doInitiate(const initiate: initiateParam; var s: storage) : (list(operation) * storage) is 
  block {
    assert(32n = Bytes.length(initiate.hashedSecret));
    assert(initiate.participant =/= Tezos.source);
    assert(initiate.refundTime > now);
    assert(initiate.payoffAmount <= initiate.totalAmount);

    const state: swapState = 
      record [
        initiator = Tezos.source;
        participant = initiate.participant;
        refundTime = initiate.refundTime;
        tokenAddress = Tezos.address(initiate.transferEntry);
        totalAmount = initiate.totalAmount;
        payoffAmount = initiate.payoffAmount;
      ];

    case s[initiate.hashedSecret] of
      | None -> s[initiate.hashedSecret] := state
      | Some(x) -> failwith("Already initiated")
    end;

    const depositTx: operation = transfer(
        initiate.transferEntry, Tezos.source, Tezos.self_address, initiate.totalAmount);
  } with (list[depositTx], s)

function doRedeem(const secret: bytes; var s: storage) : (list(operation) * storage) is
  block {
    assert(32n = Bytes.length(secret));
    const hashedSecret: bytes = Crypto.sha256(Crypto.sha256(secret));
    const swap: swapState = getSwapState(hashedSecret, s);
    assert(now < swap.refundTime);
    remove hashedSecret from map s;

    const transferEntry: contract(transferParam) = getTransferEntry(swap.tokenAddress);
    const redeemAmount: nat = abs(swap.totalAmount - swap.payoffAmount);  // we ensure that on init
    const redeemTx: operation = transfer(transferEntry, Tezos.self_address, swap.participant, redeemAmount);
    const opList: list(operation) = thirdPartyRedeem(transferEntry, swap.payoffAmount);
  } with (redeemTx # opList, s) 

function doRefund(const hashedSecret: bytes; var s: storage) : (list(operation) * storage) is
  block {
    const swap: swapState = getSwapState(hashedSecret, s);
    assert(now >= swap.refundTime);
    remove hashedSecret from map s;

    const transferEntry: contract(transferParam) = getTransferEntry(swap.tokenAddress);
    const refundTx: operation = transfer(transferEntry, Tezos.self_address, swap.initiator, swap.totalAmount);
  } with (list[refundTx], s) 

function main (const p: parameter; var s: storage) : (list(operation) * storage) is
block {
  assert(0tz = Tezos.amount);
} with case p of
  | Initiate(initiate) -> (doInitiate(initiate, s))
  | Redeem(redeem) -> (doRedeem(redeem, s))
  | Refund(refund) -> (doRefund(refund, s))
end