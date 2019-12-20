type transferParam is address * address * nat;

type initiateParam is record
  hashedSecret: bytes;
  participant: address;
  refundTime: timestamp;
  tokenAddress: address;
  redeemAmount: nat;
  payoffAmount: nat;
end

type redeemParam is record
  hashedSecret: bytes;
  secret: bytes;
end

type refundParam is record
  hashedSecret: bytes;
end

type parameter is 
| Initiate of initiateParam
| Redeem of redeemParam
| Refund of refundParam

type swapState is record
  initiator: address;
  participant: address;
  refundTime: timestamp;
  tokenAddress: address;
  redeemAmount: nat;
  payoffAmount: nat;
end

type storage is big_map(bytes, swapState) * unit;


function transfer(const tokenAddress: address; 
                  const src: address;
                  const dst: address; 
                  const value: nat) : operation is
  begin
    const transferEntry: contract(transferParam) = get_entrypoint("%transfer", tokenAddress);
    const params: transferParam = (src, dst, value);
    const op: operation = transaction(params, 0tz, transferEntry);
  end with op


function doInitiate(const initiate: initiateParam; var s: storage) : (list(operation) * storage) is 
  begin
    if (initiate.payoffAmount >= initiate.redeemAmount) then failwith("");
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
      redeemAmount = initiate.redeemAmount;
      payoffAmount = initiate.payoffAmount;
    end;

    case s.0[initiate.hashedSecret] of 
      | None -> s.0[initiate.hashedSecret] := swap
      | Some(x) -> failwith("")
    end;
    
    const depositTx: operation = transfer(
        initiate.tokenAddress, source, self_address, initiate.redeemAmount + initiate.payoffAmount);
  end with (list[depositTx], s)


function thirdPartyRedeem(const tokenAddress: address; const payoffAmount: nat) : list(operation) is
  block {
    const hasPayoff: bool = payoffAmount > 0n;
  } with case hasPayoff of
    | True -> list[transfer(tokenAddress, self_address, source, payoffAmount)]
    | False -> (nil : list(operation))
  end


function doRedeem(const redeem: redeemParam; var s: storage) : (list(operation) * storage) is 
  begin
    const swap: swapState = get_force(redeem.hashedSecret, s.0);
    if (now >= swap.refundTime) then failwith("");
    else skip;
    if (sha_256(sha_256(redeem.secret)) =/= redeem.hashedSecret) then failwith("");
    else skip;

    remove redeem.hashedSecret from map s.0;

    const redeemTx: operation = transfer(swap.tokenAddress, self_address, swap.participant, swap.redeemAmount);
    const opList: list(operation) = thirdPartyRedeem(swap.tokenAddress, swap.payoffAmount);
  end with (redeemTx # opList, s) 

function doRefund(const refund: refundParam; var s: storage) : (list(operation) * storage) is 
  begin
    const swap: swapState = get_force(refund.hashedSecret, s.0);
    if (now < swap.refundTime) then failwith("");
    else skip;
    
    remove refund.hashedSecret from map s.0;

    const refundTx: operation = transfer(
        swap.tokenAddress, self_address, swap.initiator, swap.redeemAmount + swap.payoffAmount);
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