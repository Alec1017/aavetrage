# Setup
```yarn install```

<br></br>

# Testing

The test suite forks mainnet using hardhat and upon running the tests, an account with a large portion of DAI is impersonated and sends DAI to the local hardhat address so that collateral can be supplied to aavetrage before tests are run.

## Starting mainnet fork
```yarn start-node```

## Running the tests
```yarn test```

<br></br>

# Running on Kovan

The Aavetrage contract has already been deployed to Kovan at ```0x65344669333D92c3741D0d97Bf4E9074DaaB73f1```

## Deploy contract instance
```yarn deploy-kovan```

## Calling aavetrage
```yarn aavetrage```