from os.path import dirname, join
from unittest import TestCase

from pytezos import ContractInterface, MichelsonRuntimeError

project_dir = dirname(dirname(__file__))

my_address = 'tz2TSvNTh2epDMhZHrw73nV9piBX7kLZ9K9m'
their_address = 'tz1NortRftucvAkD1J58L32EhSVrQEWJCEnB'


class FA12ContractTest(TestCase):

    @classmethod
    def setUpClass(cls):
        cls.fa = ContractInterface.create_from(join(project_dir, 'src/fa1.2.tz'))

    def test_approve(self):
        res = self.fa \
            .approve(their_address, 100) \
            .result(
                storage={
                    'ledger': {
                        my_address: {
                            'allowances': {},
                            'balance': 100
                        }
                    },
                    'totalSupply': 100
                },
                sender=my_address
            )
        self.assertEqual(100, res.big_map_diff[my_address]['allowances'].get(their_address))
    #
    # def test_get_balance(self):
    #     res = self.fa \
    #         .getBalance(my_address, 'KT1BvVxWM6cjFuJNet4R9m64VDCN2iMvjuGE') \
    #         .result(storage={
    #             'ledger': {
    #                 my_address: {
    #                     'allowances': {},
    #                     'balance': 100
    #                 }
    #             },
    #             'totalSupply': 100
    #         })
    #     print(res.operations)
