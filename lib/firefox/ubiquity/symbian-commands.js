CmdUtils.CreateCommand({
    names: ['symdoc'],
    arguments: [{role: 'object', nountype: noun_arb_text }],  
    execute: function(args) {
	url = "http://developer.symbian.org/search/search_results.php?txtSearch=" + args.object.text + "&site=sdl_collection"
        Utils.openUrlInBrowser(url);
    }
});

CmdUtils.CreateCommand({
    names: ['symbug'],
    arguments: [{role: 'object', nountype: noun_arb_text }],  
    execute: function(args) {
	url = "http://developer.symbian.org/bugs/show_bug.cgi?id=" + args.object.text
        Utils.openUrlInBrowser(url);
    }
});

CmdUtils.CreateCommand({
    names: ['sympkg'],
    arguments: [{role: 'object', nountype: noun_arb_text }],  
    execute: function(args) {
	url = "http://developer.symbian.org/main/source/packages/" + args.object.text
        Utils.openUrlInBrowser(url);
    }
});

CmdUtils.CreateCommand({
    names: ['symmcl'],
    arguments: [{role: 'object', nountype: noun_arb_text }],  
    execute: function(args) {
	url = "http://developer.symbian.org/oss/MCL/" + args.object.text
        Utils.openUrlInBrowser(url);
    }
});

CmdUtils.CreateCommand({
    names: ['symfcl'],
    arguments: [{role: 'object', nountype: noun_arb_text }],  
    execute: function(args) {
	url = "http://developer.symbian.org/oss/FCL/" + args.object.text
        Utils.openUrlInBrowser(url);
    }
});

