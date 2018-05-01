// This is the javascript unique to JellyDEX.com resting order DEX.
// It assumes:
//			- web3.js will be loaded
//			- jquery.js will be loaded


// [TODO] The following function is called after complete page load
$(document).ready(function(){
	updateAddressList();
});

// [TODO] The following function updates the address list in the navbar dropdown item
function updateAddressList() {
	$('#AddressDropdown').text(
		web3.eth.defaultAccount
	);
	web3.eth.getTransactionCount(web3.eth.accounts[0], function(error, result) {
		if (!error) {
			console.log("Account[0] Nonce+1 is: " + (result+1));
			$('#nonceText').val(result+1);
		} else {
			console.error(error);
		}
	});
}