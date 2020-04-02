var SimpleStorage = artifacts.require("./SimpleStorage.sol");
var OrdenToken = artifacts.require("./OrdenToken.sol");
var OrdenTokenSale = artifacts.require("./OrdenToken.sol");

module.exports = function(deployer) {
  deployer.deploy(SimpleStorage);
  deployer.deploy(OrdenToken);
  deployer.deploy(OrdenTokenSale);
};
