CmdUtils.CreateCommand({
    names: ['xref-linux'],
    arguments: [{role: 'object', nountype: noun_arb_text }],
    execute: function(args) {
    url = "http://lxr.free-electrons.com/ident?i=" + args.object.text
    Utils.openUrlInBrowser(url);
    }
});

