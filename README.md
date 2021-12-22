# Blake3 For Solidity

This is an implementation of the blake3 hash function in solidity.



## Building
You will need to pull down the library dependencies. Run:

```
git submodule update --init --recursive
```

We use the [foundry tools](https://github.com/gakonst/foundry) for building and testing.

Static builds of the `forge` and `cast` tools can be found [here](https://github.com/themeliolabs/artifacts).

To build, run:
```
$ forge build
```


## Debugging

We have the option of logging via two frameworks: [hardhat](https://github.com/nomiclabs/hardhat) and [ds-test](https://github.com/dapphub/ds-test)

To log with `ds-test`, add this line to the top of your solidity file:
```
import "hardhat-core/console.sol";
```

Then you can print out debugging information like this:
```
console.log("Example print");
```

To log with `ds-test`, add this line to the top of your solidity file:
```
import "ds-test/test.sol";
```

Then you can print out debugging information like this:
```
emit log("Other example print");
```


## Testing

Run:
```
$ env RUST_LOG=forge=trace forge test --verbosity 3
```