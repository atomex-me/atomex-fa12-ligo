from os.path import dirname, join
from unittest import TestCase

from pytezos import ContractInterface, pytezos, format_timestamp, MichelsonRuntimeError

fa_address = 'KT1MvySWj4nzL8mdsVGzpxrmUxZeWTvLRxBf'
source = 'tz1irF8HUsQp2dLhKNMhteG1qALNU9g3pfdN'
party = 'tz1h3rQ8wBxFd8L9B3d7Jhaawu6Z568XU3xY'
proxy = 'tz1grSQDByRpnVs7sPtaprNZRp531ZKz6Jmm'
secret = 'dca15ce0c01f61ab03139b4673f4bd902203dc3b898a89a5d35bad794e5cfd4f'
hashed_secret = '05bce5c12071fbca95b13d49cb5ef45323e0216d618bb4575c519b74be75e3da'
empty_storage = [{}, None]
project_dir = dirname(dirname(__file__))


class AtomexContractTest(TestCase):

    @classmethod
    def setUpClass(cls):
        cls.atomex = ContractInterface.create_from(join(project_dir, 'src/atomex.tz'))
        cls.fa12 = pytezos.contract(fa_address)
        cls.maxDiff = None

    def assertTransfer(self, src, dst, amount, parameters):
        params = self.fa12.contract.parameter.decode(parameters)
        self.assertEqual([src, dst, amount], params['transfer'])

    def test_no_tez(self):
        now = pytezos.now()
        with self.assertRaises(MichelsonRuntimeError):
            self.atomex \
                .initiate(hashedSecret=hashed_secret,
                          participant=party,
                          refundTime=now + 6 * 3600,
                          tokenAddress=fa_address,
                          totalAmount=1000,
                          payoffAmount=0) \
                .with_amount(1000) \
                .result(storage=empty_storage,
                        source=source)

    def test_initiate(self):
        now = pytezos.now()
        res = self.atomex \
            .initiate(hashedSecret=hashed_secret,
                      participant=party,
                      refundTime=now + 6 * 3600,
                      tokenAddress=fa_address,
                      totalAmount=1000,
                      payoffAmount=10) \
            .result(storage=empty_storage,
                    source=source)

        big_map_diff = {
            hashed_secret: {
                'initiator': source,
                'participant': party,
                'payoffAmount': 10,
                'totalAmount': 1000,
                'refundTime': format_timestamp(now + 6 * 3600),
                'tokenAddress': fa_address
            }
        }
        self.assertDictEqual(big_map_diff, res.big_map_diff)
        self.assertEqual(empty_storage, res.storage)
        self.assertEqual(1, len(res.operations))
        self.assertTransfer(src=source,
                            dst=res.operations[0]['source'],
                            amount=1000,
                            parameters=res.operations[0]['parameters'])

    def test_initiate_proxy(self):
        now = pytezos.now()
        res = self.atomex \
            .initiate(hashedSecret=hashed_secret,
                      participant=party,
                      refundTime=now + 6 * 3600,
                      tokenAddress=fa_address,
                      totalAmount=1000,
                      payoffAmount=10) \
            .result(storage=empty_storage,
                    sender=proxy,
                    source=source)

        big_map_diff = {
            hashed_secret: {
                'initiator': source,
                'participant': party,
                'payoffAmount': 10,
                'totalAmount': 1000,
                'refundTime': format_timestamp(now + 6 * 3600),
                'tokenAddress': fa_address
            }
        }
        self.assertDictEqual(big_map_diff, res.big_map_diff)
        self.assertEqual(empty_storage, res.storage)
        self.assertEqual(1, len(res.operations))
        self.assertTransfer(src=source,
                            dst=res.operations[0]['source'],
                            amount=1000,
                            parameters=res.operations[0]['parameters'])

    def test_initiate_same_secret(self):
        now = pytezos.now()
        initial_storage = [{
            hashed_secret: {
                'initiator': source,
                'participant': party,
                'refundTime': format_timestamp(now + 6 * 3600),
                'tokenAddress': fa_address,
                'totalAmount': 1000,
                'payoffAmount': 0
            }
        }, None]

        with self.assertRaises(MichelsonRuntimeError):
            self.atomex \
                .initiate(hashedSecret=hashed_secret,
                          participant=party,
                          refundTime=now + 6 * 3600,
                          tokenAddress=fa_address,
                          totalAmount=1000,
                          payoffAmount=0) \
                .result(storage=initial_storage,
                        source=source)

    def test_initiate_payoff_overflow(self):
        now = pytezos.now()

        with self.assertRaises(MichelsonRuntimeError):
            self.atomex \
                .initiate(hashedSecret=hashed_secret,
                          participant=party,
                          refundTime=now + 6 * 3600,
                          tokenAddress=fa_address,
                          totalAmount=100,
                          payoffAmount=101) \
                .result(storage=empty_storage,
                        source=source)

    def test_initiate_in_the_past(self):
        now = pytezos.now()
        with self.assertRaises(MichelsonRuntimeError):
            self.atomex \
                .initiate(hashedSecret=hashed_secret,
                          participant=party,
                          refundTime=now - 6 * 3600,
                          tokenAddress=fa_address,
                          totalAmount=1000,
                          payoffAmount=0) \
                .result(storage=empty_storage,
                        source=source)

    def test_initiate_same_party(self):
        now = pytezos.now()
        with self.assertRaises(MichelsonRuntimeError):
            self.atomex \
                .initiate(hashedSecret=hashed_secret,
                          participant=party,
                          refundTime=now + 6 * 3600,
                          tokenAddress=fa_address,
                          totalAmount=1000,
                          payoffAmount=0) \
                .result(storage=empty_storage,
                        source=party)

    def test_redeem_by_third_party(self):
        now = pytezos.now()
        initial_storage = [{
            hashed_secret: {
                'initiator': source,
                'participant': party,
                'refundTime': format_timestamp(now + 6 * 3600),
                'tokenAddress': fa_address,
                'totalAmount': 1000,
                'payoffAmount': 10
            }
        }, None]

        res = self.atomex \
            .redeem(secret) \
            .result(storage=initial_storage, source=source)

        self.assertDictEqual({hashed_secret: None}, res.big_map_diff)
        self.assertEqual(2, len(res.operations))
        self.assertTransfer(src=res.operations[0]['source'],
                            dst=party,
                            amount=990,
                            parameters=res.operations[0]['parameters'])
        self.assertTransfer(src=res.operations[0]['source'],
                            dst=source,
                            amount=10,
                            parameters=res.operations[1]['parameters'])

    def test_redeem_after_expiration(self):
        now = pytezos.now()
        initial_storage = [{
            hashed_secret: {
                'initiator': source,
                'participant': party,
                'refundTime': format_timestamp(now - 60),
                'tokenAddress': fa_address,
                'totalAmount': 1000,
                'payoffAmount': 10
            }
        }, None]

        with self.assertRaises(MichelsonRuntimeError):
            self.atomex \
                .redeem(secret) \
                .result(storage=initial_storage, source=party)

    def test_redeem_invalid_secret(self):
        now = pytezos.now()
        initial_storage = [{
            hashed_secret: {
                'initiator': source,
                'participant': party,
                'refundTime': format_timestamp(now - 60),
                'tokenAddress': fa_address,
                'totalAmount': 1000,
                'payoffAmount': 10
            }
        }, None]

        with self.assertRaises(MichelsonRuntimeError):
            self.atomex \
                .redeem('a' * 32) \
                .result(storage=initial_storage, source=source)

    def test_redeem_with_money(self):
        now = pytezos.now()
        initial_storage = [{
            hashed_secret: {
                'initiator': source,
                'participant': party,
                'refundTime': format_timestamp(now - 60),
                'tokenAddress': fa_address,
                'totalAmount': 1000,
                'payoffAmount': 10
            }
        }, None]

        with self.assertRaises(MichelsonRuntimeError):
            self.atomex \
                .redeem(secret) \
                .with_amount(100000) \
                .result(storage=initial_storage, source=source)

    def test_refund(self):
        now = pytezos.now()
        initial_storage = [{
            hashed_secret: {
                'initiator': source,
                'participant': party,
                'refundTime': format_timestamp(now - 60),
                'tokenAddress': fa_address,
                'totalAmount': 1000,
                'payoffAmount': 10
            }
        }, None]

        res = self.atomex \
            .refund(hashed_secret) \
            .result(storage=initial_storage, source=source)

        self.assertDictEqual({hashed_secret: None}, res.big_map_diff)
        self.assertEqual(1, len(res.operations))
        self.assertTransfer(src=res.operations[0]['source'],
                            dst=source,
                            amount=1000,
                            parameters=res.operations[0]['parameters'])

    def test_third_party_refund(self):
        now = pytezos.now()
        initial_storage = [{
            hashed_secret: {
                'initiator': source,
                'participant': party,
                'refundTime': format_timestamp(now - 60),
                'tokenAddress': fa_address,
                'totalAmount': 1000,
                'payoffAmount': 10
            }
        }, None]

        res = self.atomex \
            .refund(hashed_secret) \
            .result(storage=initial_storage, source=party)

        self.assertDictEqual({hashed_secret: None}, res.big_map_diff)
        self.assertEqual(1, len(res.operations))
        self.assertTransfer(src=res.operations[0]['source'],
                            dst=source,
                            amount=1000,
                            parameters=res.operations[0]['parameters'])

    def test_refund_before_expiration(self):
        now = pytezos.now()
        initial_storage = [{
            hashed_secret: {
                'initiator': source,
                'participant': party,
                'refundTime': format_timestamp(now + 60),
                'tokenAddress': fa_address,
                'totalAmount': 1000,
                'payoffAmount': 10
            }
        }, None]

        with self.assertRaises(MichelsonRuntimeError):
            self.atomex \
                .refund(hashed_secret) \
                .result(storage=initial_storage, source=source)

    def test_refund_non_existent(self):
        with self.assertRaises(MichelsonRuntimeError):
            self.atomex \
                .refund(hashed_secret) \
                .result(storage=empty_storage, source=source)

    def test_refund_with_money(self):
        now = pytezos.now()
        initial_storage = [{
            hashed_secret: {
                'initiator': source,
                'participant': party,
                'refundTime': format_timestamp(now + 60),
                'tokenAddress': fa_address,
                'totalAmount': 1000,
                'payoffAmount': 10
            }
        }, None]

        with self.assertRaises(MichelsonRuntimeError):
            self.atomex \
                .refund(hashed_secret) \
                .with_amount(100000) \
                .result(storage=initial_storage, source=source)
