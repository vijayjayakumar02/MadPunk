const PunkCoin = artifacts.require("../contracts/punkCoin.sol");
const Madpunk = artifacts.require("./contracts/Madpunk.sol");

module.exports = async function (deployer) {
    await deployer.deploy(PunkCoin);
    const token = await PunkCoin.deployed();
  
    await deployer.deploy(Madpunk, token.address);
  };
  