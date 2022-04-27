# Blake3 For Solidity

This is an implementation of the blake3 hash function in solidity.



## Building
You will need to pull down the library dependencies. Run:

```
git submodule update --init --recursive
```

We use the [foundry tools](https://github.com/gakonst/foundry) for building and testing.

Static builds of the `forge` and `cast` tools can be found [here](https://github.com/themeliolabs/artifacts).

If you would prefer to install them via `cargo`, run:

```
$ cargo install --git https://github.com/gakonst/foundry --bin forge --locked
$ cargo install --git https://github.com/gakonst/foundry --bin cast --locked
```




To build, run:
```
$ forge build
```


## Debugging


To log with `ds-test`, add this line to the top of your solidity file:
```
import "forge-std/Test.sol";
```

Then you can print out debugging information like this:
```
emit log("Other example print");
```


## Testing

Run:
```
$ env RUST_LOG=forge=trace forge test -vvv
```
