Now that we know how links and monitors, we can start with Tasks. 

Know that tasks by default are linked if you expect a response. The `Task.await` and `Task.yield` commands are very useful! They work with messages though that you aren't supposed to touch... 

Start a very simple task that returns `:ok` and see what is in your mailbox with `flush`. 

The goal of this exercise is to start a task with `Task.async`, after which you need to collect the result manually. __Do not use `Task.await`, `Task.yield` or any other `Task.*` functions!__