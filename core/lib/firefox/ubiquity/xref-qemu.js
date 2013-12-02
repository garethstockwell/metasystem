CmdUtils.CreateCommand({
    names: ['xref-qemu'],
    arguments: [{role: 'object', nountype: noun_arb_text }],
    execute: function(args) {
    url = "http://code.metager.de/source/search?q=&defs=" + args.object.text + "&refs=&path=&hist=&type="
    Utils.openUrlInBrowser(url);
    }
});

