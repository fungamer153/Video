opt server_output = "src/Server/Modules/ServerNetwork.luau"
opt client_output = "src/Client/Modules/ClientNetwork.luau"
opt casing = "camelCase"

event StartTutorial = {
    from: Server,
    type: Reliable,
    call: ManyAsync
}

event VideoComplete = {
    from: Server,
    type: Reliable,
    call: ManyAsync
}

funct StartVideo = {
    call: Async,
    args: (type: string.utf8),
    rets: enum { Success, Fail }
}

event IncrementProgress = {
    from: Client,
    type: Reliable,
    call: ManyAsync
}

funct ChangeChannelName = {
    call: Async,
    args: (text: string.utf8),
    rets: enum { Success, Fail }
}