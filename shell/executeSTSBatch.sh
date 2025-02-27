# Load environment variables
source .env

# Deploy the system using the BondScripts contract
forge script ./script/TestAuthBatch.s.sol:TestAuthBatch --sig "run(bool)()" $1 --slow -vvv --sender $SIGNER_ADDRESS --rpc-url $RPC_URL