# Load environment variables
source .env

# Deploy the system using the BondScripts contract
forge script ./script/TestAuthBatch.s.sol:TestAuthBatch --sig "run()()" --slow -vvv --sender $GOV_ADDRESS