CmdUtils.CreateCommand({
    names: ['qdoc'],
    arguments: [{role: 'object', nountype: noun_arb_text },
                {role: 'source', nountype: noun_arb_text}],  
    execute: function(args) {
        var symbolName = args.object.text.replace("::", "-")
        var version = args.source.text
    url = "http://doc.qt-project.org/" + version + "-snapshot/" + symbolName + ".html"
        Utils.openUrlInBrowser(url);
    }
});

CmdUtils.CreateCommand({
    names: ['qtbug'],
    arguments: [{role: 'object', nountype: noun_arb_text }],  
    execute: function(args) {
    url = "http://bugreports.qt-project.org/browse/QTBUG-" + args.object.text
        Utils.openUrlInBrowser(url);
    }
});

CmdUtils.CreateCommand({
    names: ['qtmbug'],
    arguments: [{role: 'object', nountype: noun_arb_text }],  
    execute: function(args) {
    url = "http://bugreports.qt-project.org/browse/QTMOBILITY-" + args.object.text
        Utils.openUrlInBrowser(url);
    }
});

