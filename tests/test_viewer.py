from os.path import dirname, join
from unittest import TestCase

from pytezos import ContractInterface, pytezos

project_dir = dirname(dirname(__file__))
user_address = 'tz1irF8HUsQp2dLhKNMhteG1qALNU9g3pfdN'
party_address = 'tz1h3rQ8wBxFd8L9B3d7Jhaawu6Z568XU3xY'
viewer_address = 'KT1DoLDQS6LmUuHjzcfcKCvtd6nfARE86XrJ'  # Babylonnet (TODO: change in the next season)


class FAViewerTest(TestCase):

    @classmethod
    def setUpClass(cls):
        cls.fa12 = ContractInterface.create_from(join(project_dir, 'samples/fa1.2.tz'))
        cls.viewer = pytezos.contract(viewer_address)
        cls.maxDiff = None

    def test_get_total_supply(self):
        res = self.fa12 \
            .getTotalSupply(None, f'{viewer_address}%viewNat') \
            .result(storage={'ledger': {}, 'totalSupply': 300})
        
        parameters = res.operations[0]['parameters']
        self.assertEqual('viewNat', parameters['entrypoint'])
        self.assertEqual({'int': '300'}, parameters['value'])

    def test_get_balance(self):
        res = self.fa12 \
            .getBalance(user_address, f'{viewer_address}%viewNat') \
            .result(storage={
                'ledger': {user_address: {'allowances': {}, 'balance': 200}}, 
                'totalSupply': 200})
        
        parameters = res.operations[0]['parameters']
        self.assertEqual('viewNat', parameters['entrypoint'])
        self.assertEqual({'int': '200'}, parameters['value'])

    def test_get_allowance(self):
        res = self.fa12 \
            .getAllowance(user_address, party_address, f'{viewer_address}%viewNat') \
            .result(storage={
                'ledger': {user_address: {
                    'allowances': {party_address: 100}, 
                    'balance': 300}}, 
                'totalSupply': 300})
        
        parameters = res.operations[0]['parameters']
        self.assertEqual('viewNat', parameters['entrypoint'])
        self.assertEqual({'int': '100'}, parameters['value'])
