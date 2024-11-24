-include .env

.PHONY: help all clean install format snapshot anvil deploy 

help: 
	@echo "Usage:"
	@echo " make deployCrypticFlowRouter [ARGS=...]\n	example: make deploy ARGS=\"--network sepolia\""

all:; clean remove install update build

clean:; forge clean

remove:; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install:; forge install https://github.com/OpenZeppelin/openzeppelin-contracts --no-commit && https://github.com/transmissions11/solmate --no-commit && https://github.com/foundry-rs/forge-std --no-commit

update:; forge update

build:; forge build

test:; forge test

format:; forge fmt

snapshot:; forge snapshot

anvil:; anvil --block-time 1

NETWORK_ARGS := --rpc-url $(ANVIL_RPC_URL) --account anvilKey1 --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --broadcast -vvvv

ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --account devKeyAccount1 --sender 0x3da99E808a621112b91d108De426439813cF6005 --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) --via-ir
endif

deployCrypticFlowRouter:
	@forge script script/DeployCrypticFlowRouter.s.sol:DeployCrypticFlowRouter $(NETWORK_ARGS)

deployTestTokens:
	@forge script script/DeployTestTokens.s.sol:DeployTestTokens $(NETWORK_ARGS)