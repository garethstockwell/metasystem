CmdUtils.CreateCommand({
    names: ['xref-android'],
    arguments: [{role: 'object', nountype: noun_arb_text }],
    execute: function(args) {
    url = "http://androidxref.com/4.3_r2.1/search?q=&defs=" + args.object.text + "&refs=&path=&hist=&project=abi&project=bionic&project=bootable&project=build&project=cts&project=dalvik&project=developers&project=development&project=device&project=docs&project=external&project=frameworks&project=hardware&project=libcore&project=libnativehelper&project=ndk&project=packages&project=pdk&project=prebuilts&project=sdk&project=system&project=tools"
        Utils.openUrlInBrowser(url);
    }
});

