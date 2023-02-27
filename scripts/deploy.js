const hre = require('hardhat');

async function main() {
  // deployment for madpunk contract
  const Madpunk = await hre.ethers.getContractFactory('Madpunk');
  const madpunk = await Madpunk.deploy("Deployed Madpunk!");
  await madpunk.deployed();

  console.log('Madpunk Contract deployed to:', madpunk.address);

  // deployment for punkCoin contract
  const Punkcoin = await hre.ethers.getContractFactory('PunkCoin');
  const punkcoin = await Punkcoin.deploy();
  await punkcoin.deployed();

  console.log('Punkcoin contract deployed to:', punkcoin.address);

}

//error handling
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });