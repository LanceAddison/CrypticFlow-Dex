# CrypticFlow Dex

# About

This project is meant to be a clone of the Uniswap V2 protocol. Users can add and remove liquidity as well as swap between ERC20 tokens.

- [CrypticFlow Dex](#crypticflow-dex)
- [About](#about)
- [Getting Started](#getting-started)
  - [Requirements](#requirements)
  - [Quickstart](#quickstart)
- [Usage](#usage)
  - [Start a local node](#start-a-local-node)
  - [Deploy](#deploy)
  - [Deploy - Other Network](#deploy---other-network)
  - [Testing](#testing)
    - [Test coverage](#test-coverage)
- [Deployment to a testnet or mainnet](#deployment-to-a-testnet-or-mainnet)
  - [Scripts](#scripts)
  - [Estimated gas](#estimated-gas)
- [Formatting](#formatting)
- [Additional Info:](#additional-info)
- [Acknowledgement](#acknowledgement)
- [Thank you!](#thank-you)

# Getting Started

## Requirements

- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
  - You'll know you did it right if you can run `git --version` and you see a response like `git version x.x.x`
- [foundry](https://getfoundry.sh/)
  - You'll know you did it right if you can run `forge --version` and you see a response like `forge 0.2.0 (816e00b 2023-03-16T00:05:26.396218Z)`

## Quickstart

```
git clone https://github.com/LanceAddison/CrypticFlow-Dex.git
cd crypticflow-dex
forge build
```

# Usage

**NOTE** Make sure the required directories are installed in the `/lib` folder.

[See below](#additional-info)

## Start a local node

```
make anvil
```

## Deploy

This will default to your local node. You need to have it running in another terminal in order for it to deploy.

You'll want to set your `ANVIL_RPC_URL` as an environment variable in a .env file. This can be found when you start your local node. It should look like ```127.0.0.1:8545```.

You'll also want to set `anvilKey1` in a keystore file using the default anvil key.

[See below](#additional-info)

In the `Makefile` where `NETWORK_ARGS` is set for the anvil chain change the public key next to `--sender`.

```
make deployCrypticFlowRouter
```

Optionally you can deploy test tokens to anvil.

```
make deployTestTokens
```

**NOTE** The deployed test tokens have not been tested. It isn't recommended to deploy these on mainnet.

## Deploy - Other Network

[See below](#deployment-to-a-testnet-or-mainnet)

## Testing

```
make test
```

### Test coverage

```
forge coverage
```

# Deployment to a testnet or mainnet

1. Setup environment variables

You'll want to set your `SEPOLIA_RPC_URL` as environment variable in a .env file.

- `SEPOLIA_RPC_URL`: This is the url of the sepolia testnet node you're working with. You can get one for free from [Alchemy](https://alchemy.com/?a=67c802981)

Optionally, you can add your `ETHERSCAN_API_KEY` if you want to verify your contract on Etherscan.

2. Setup your private key

You'll want to set `devKeyAccount1` in a keystore file using your private key.

[See below](#additional-info)

3. Setup your public key

You'll want to set the public key that goes with your private key in the `Makefile` next to `--sender` in the `ifeq` condition. 

You should also set the `feeToAddress` variable in the `DeployCrypticFlowFactory` and `DeployCrypticFlowRouter` files.

1. Get testnet ETH and LINK

Get some testnet ETH and LINK at a faucet such as [faucets.chain.link](https://faucets.chain.link/). They should show up in your wallet.

2. Deploy

```
make deployCrypticFlowRouter ARGS="--network sepolia"
```

Optionally you can deploy test tokens to sepolia.

```
make deployTestTokens ARGS="--network sepolia"
```

**NOTE** The deployed test tokens have not been tested. It isn't recommended to deploy these on mainnet.

## Scripts

Instead of scripts, we can use the `cast` command to interact with the contract. 

For example, on Anvil:

- First load your .env variables into the terminal

```
source .env
```

1. Approve tokens for router

```
cast send [Token0] "approve(address,uint256)(bool)" [DeployedRouterAddress] [Amount0] --account anvilKey1 --password [Password]

cast send [Token1] "approve(address,uint256)(bool) [DeployedRouterAddress] [Amount1] --account anvilKey1 --password [Password]
```

2. Add liquidity

```
cast call [DeployedRouterAddress] "addLiquidity(address,address,uint256,uint256,uint256,uint256,address)(uint256,uint256,uint256)" [Token0] [Token1] [Amount0] [Amount1] [Amount0Min] [Amount1Min] [To] --acount anvilKey1 --password [Password]
```

## Estimated gas

You can estimate how much gas things cost by running:

```
make snapshot
```

You'll see an output file called `.gas-snapshot`

# Formatting

To format your code run:

```
make format
```

# Additional Info:

<h3>Creating a keystore file</h3>

**NOTE** It's better to do this directly in your computers built in command line. Code editors like VS Code can save your command history potentially exposing your private key.

1. Add your private key to a keystore file

To add your private key to a keystore file run:

```
cast wallet --import [accountName] --interactive
```

2. Enter your private key

3. Enter a secure password

**NOTE** It wont show your private key or password on screen while you type them.

<h3>If the required directories need to be reinstalled:</h3>

1. Remove directories and Git submodules

```
make remove
```

2. Install the required directories

```
make install
```

# Acknowledgement

- [Ivan Kuznetsov's]("https://jeiwan.net") Uniswap V2 series greatly helped me in writing and understanding the Uniswap V2 contracts.

# Thank you!

If you appreciated this, feel free to follow me on X(formerly Twitter) [@LanceAddison17](https://x.com/LanceAddison17).

You can also contact me on there.
