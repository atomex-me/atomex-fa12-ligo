# View methods
Viewer contracts:
* Babylonnet `KT1DoLDQS6LmUuHjzcfcKCvtd6nfARE86XrJ`
* Mainnet `TODO(m-kus)`

### GetBalance
```sh
POST https://rpc.tzkt.io/babylonnet/chains/main/blocks/head/helpers/scripts/run_operation
```

##### Payload
```json
{"chain_id": %chain_id%,
 "operation": {"branch": %branch%,
               "contents": [{"amount": "0",
                             "counter": %counter%,
                             "destination": %fa_contract_address%,
                             "fee": "100000",
                             "gas_limit": "800000",
                             "kind": "transaction",
                             "parameters": {"entrypoint": "getBalance",
                                            "value": {"args": [{"string": %token_holder_address%},
                                                               {"string": "KT1DoLDQS6LmUuHjzcfcKCvtd6nfARE86XrJ%viewNat"}],
                                                      "prim": "Pair"}},
                             "source": %source%,
                             "storage_limit": "60000"}],
               "signature": "sigUHx32f9wesZ1n2BWpixXz4AQaZggEtchaQNHYGRCoWNAXx45WGW2ua3apUUUAGMLPwAU41QoaFCzVSL61VaessLg4YbbP"}}
```

##### Response (stripped)
```json
{"contents": [{"metadata": {"internal_operation_results": [{"parameters": {"entrypoint": "viewNat",
                                                                           "value": {"int": "0"}}}]}}]}
```