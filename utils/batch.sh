# Load environment variables
source .env

forge script ./script/TestBatch.s.sol:TestBatch --sig "run()()" --rpc-url $RPC_URL --private-key $DEPLOYER_KEY --slow --ffi -vvvvv \
# --broadcast --verify --etherscan-api-key $ETHERSCAN_KEY #\ # uncomment to broadcast to the network