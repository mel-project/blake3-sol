# Blake3 For Solidity

This is an implementation of the blake3 hash function in solidity.



## Building

We use the [foundry tools](https://github.com/gakonst/foundry) for building and testing.

Static builds of the `forge` and `cast` tools can be found [here](https://github.com/themeliolabs/artifacts).

To build, run:
```
$ forge build
```


## Testing

Run:
```
$ env RUST_LOG=forge=trace forge test --verbosity 3
```