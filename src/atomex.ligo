type tokenInterface is
| Transfer of (address * address * nat)
| Approve of (address * nat)
| GetAllowance of (address * address * contract(nat))
| GetBalance of (address * contract(nat))
| GetTotalSupply of (unit * contract(nat))

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
  hashedSecret: bytes;
  initiator: address;
  participant: address;
  refundTime: timestamp;
  tokenAddress: address;
  redeemAmount: nat;
  payoffAmount: nat;
end

type storage is map(bytes, swapState);


function transfer(const tokenAddress: address; 
                  const src: address;
                  const dst: address; 
                  const value: nat) : operation is
  begin
    const tokenContract: contract(tokenInterface) = get_contract(tokenAddress);
    const tx: tokenInterface = Transfer(src, dst, value);
    const op: operation = transaction(tx, 0tz, tokenContract);
  end with (op)


function doInitiate(const initiate: initiateParam; var s: storage) : (list(operation) * storage) is 
  begin
    // TODO: check hashed secret length is 32
    // TODO: check refund timestamp is not expired
    // TODO: check payoff < amount

    const swap: swapState = record
      hashedSecret = initiate.hashedSecret;
      initiator = source;
      participant = initiate.participant;
      refundTime = initiate.refundTime;
      tokenAddress = initiate.tokenAddress;
      redeemAmount = initiate.redeemAmount;
      payoffAmount = initiate.payoffAmount;
    end;

    case s[initiate.hashedSecret] of 
      | None -> s[initiate.hashedSecret] := swap
      | Some(x) -> failwith ("")
    end;
    
    const op: operation = transfer(initiate.tokenAddress, source, self_address, initiate.redeemAmount);
    const opList: list(operation) = list op; end;
  end with ( opList, s ) 


function doRedeem(const redeem: redeemParam; var s: storage) : (list(operation) * storage) is 
  begin
    const swap: swapState = get_force(redeem.hashedSecret, s);
    if (now >= swap.refundTime) then failwith ("");
    else skip;
    if (sha_256(sha_256(redeem.secret)) =/= redeem.hashedSecret) then failwith ("");
    else skip;

    //s[redeem.hashedSecret] := None;

    const op: operation = transfer(swap.tokenAddress, self_address, swap.participant, swap.redeemAmount);
    const opList: list(operation) = list op; end;
    // if (swap.payoffAmount > 0) then
    //   const pop: operation = transfer (swap.tokenAddress, self_address, source, swap.payoffAmount);
    //   opList := pop # opList;
    // end
    // else skip;
  end with ( opList, s ) 

function doRefund(const refund: refundParam; var s: storage) : (list(operation) * storage) is 
  begin
    const swap: swapState = get_force(refund.hashedSecret, s);
    if (now < swap.refundTime) then failwith ("");
    else skip;
    
    //s[refund.hashedSecret] := None;

    const op: operation = transfer(swap.tokenAddress, self_address, swap.initiator, swap.redeemAmount);
    const opList: list(operation) = list op; end;
  end with ( opList, s ) 

function main (const p: parameter; var s: storage) : (list(operation) * storage) is
block {
  if amount =/= 0tz then failwith("This contract do not accept tez");
  else skip;
} with case p of
  | Initiate(initiate) -> (doInitiate(initiate, s))
  | Redeem(redeem) -> (doRedeem(redeem, s))
  | Refund(refund) -> (doRefund(refund, s))
end