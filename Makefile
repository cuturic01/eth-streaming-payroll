.PHONY: localnet deploy

compile:
	npx hardhat compile

localnet:
	npx hardhat node

deploy: compile
	npx hardhat deploy-eth-streamer --network localhost