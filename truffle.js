module.exports = {
  networks:{
    development:{
      host:"127.0.0.1",
      port:"7545",
      network_id:"*" // any
    },
    rinkeby:{
      host:"127.0.0.1",
      port:"8545",
      network_id:"4",
      gas:"4700000"
    }
  }
};
