type transferParam is address * (address * nat);

type initiateParam is record
  hashedSecret: bytes;
  participant: address;
  refundTime: timestamp;
  tokenAddress: address;
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

type storage is big_map(bytes, swapState) * unit;

function transfer(const tokenAddress: address; 
                  const src: address;
                  const dst: address; 
                  const value: nat) : operation is
  begin
    const transferEntry: contract(transferParam) = get_entrypoint("%transfer", tokenAddress);
    const params: transferParam = (src, (dst, value));
    const op: operation = transaction(params, 0tz, transferEntry);
  end with op

function doInitiate(const initiate: initiateParam; var s: storage) : (list(operation) * storage) is 
  begin
    if (initiate.payoffAmount > initiate.totalAmount) then failwith("");
    else skip;
    if (initiate.refundTime <= now) then failwith("");
    else skip;
    if (32n =/= size(initiate.hashedSecret)) then failwith("");
    else skip;
    if (initiate.participant = source) then failwith("");
    else skip;

    const swap: swapState = record
      initiator = source;
      participant = initiate.participant;
      refundTime = initiate.refundTime;
      tokenAddress = initiate.tokenAddress;
      totalAmount = initiate.totalAmount;
      payoffAmount = initiate.payoffAmount;
    end;

    case s.0[initiate.hashedSecret] of 
      | None -> s.0[initiate.hashedSecret] := swap
      | Some(x) -> failwith("")
    end;
    
    const depositTx: operation = transfer(
        initiate.tokenAddress, source, self_address, initiate.totalAmount);
  end with (list[depositTx], s)

function thirdPartyRedeem(const tokenAddress: address; const payoffAmount: nat) : list(operation) is
  block {
    const hasPayoff: bool = payoffAmount > 0n;
  } with case hasPayoff of
    | True -> list[transfer(tokenAddress, self_address, source, payoffAmount)]
    | False -> (nil : list(operation))
  end

function doRedeem(const secret: bytes; var s: storage) : (list(operation) * storage) is
  begin
    if (32n =/= size(secret)) then failwith("");
    else skip;
    const hashedSecret: bytes = sha_256(sha_256(secret));
    const swap: swapState = get_force(hashedSecret, s.0);
    if (now >= swap.refundTime) then failwith("");
    else skip;

    remove hashedSecret from map s.0;

    const redeemAmount: nat = abs(swap.totalAmount - swap.payoffAmount);  // we ensure that on init
    const redeemTx: operation = transfer(swap.tokenAddress, self_address, swap.participant, redeemAmount);
    const opList: list(operation) = thirdPartyRedeem(swap.tokenAddress, swap.payoffAmount);
  end with (redeemTx # opList, s) 

function doRefund(const hashedSecret: bytes; var s: storage) : (list(operation) * storage) is
  begin
    const swap: swapState = get_force(hashedSecret, s.0);
    if (now < swap.refundTime) then failwith("");
    else skip;
    
    remove hashedSecret from map s.0;

    const refundTx: operation = transfer(
        swap.tokenAddress, self_address, swap.initiator, swap.totalAmount);
  end with (list[refundTx], s) 

function main (const p: parameter; var s: storage) : (list(operation) * storage) is
block {
  if 0tz =/= amount then failwith("This contract do not accept tez");
  else skip;
} with case p of
  | Initiate(initiate) -> (doInitiate(initiate, s))
  | Redeem(redeem) -> (doRedeem(redeem, s))
  | Refund(refund) -> (doRefund(refund, s))
end