---
layout: default
---
# GenServer

A GenServer, or generic server, is a process that has 2 parts defined in its module. The API and Server part.

## Usage Agent vs Task vs GenServer
If you want to know the difference, I couldn't explain it more obvious than this post: https://elixirforum.com/t/agent-task-genserver-genevent-what-do-you-use-it-for/2416/2?u=wfransen

If you read the above post, skip to the next chapter. If you want a quick summary:
 * GenServer, as the name implies, is a generic server used most of the times for a variety of use cases.
 * Agent is basically just a simplified GenServer.
 * Task is easy to use for async jobs which give an output. Their API such as Task.await or Task.yield is very useful. (Not to mention that its less work for the garbage collector)

## Overview GenServer behaviour
Look at the slides for an overview of the GenServer API.

 * `[CLIENT]` GenServer.start or GenServer.start_link starts a GenServer process. After this the init
 * `[SERVER]` init function is called. At this point the server process is alive, but this phase shouldn't take too long. If a lot of startup work has to be done after initializing the process, consider `handle_continue`. _Note that the argument from GenServer.start or GenServer.start_link is passed to the init function. This is most of the time a named list._
 * `[SERVER]` After the init function is complete, a recursive loop function with a receive block is called. This should be familiar. 
 * `[CLIENT | SERVER]` The client will most often call a function, such as `MyGenServer.Counter.addone/1 or /0`(depends whether the process is name registered or not, more about that later), which will call the underlying `GenServer.cast` / `call`/ or the basic `send`.
    * Beware! cast is asynchronous, call is synchronous, send is how you define it. 
    * You can specify your behaviour with `handle_cast`, `handle_call` and `handle_info`.
 * `[SERVER]` The `terminate` callback is called when `GenServer.terminate` is called.

 ## A basic task handler
 Image we have a GenServer keeping track of how many tasks can be executed at the same time (and send the response back to the initializer). This means that the GenServer will:
  * Start tasks
  * accumulate the tasks
  * manage how many tasks are executed at the same time
  * send the response back to the caller
  * perhaps make an API call available for the status

  That's a lot to maintain. Let us start with the beginning, starting the GenServer and registering the process.

  ### Initializing the GenServer

If we start at the beginning, we'll define our module with the necessary use statement:

```elixir
defmodule MyGenServer do
  use GenServer

end
```

When you run this, you should see something like this:

```elixir
warning: function init/1 required by behaviour GenServer is not implemented (in module MyGenServer).

We will inject a default implementation for now:

    def init(init_arg) do
      {:ok, init_arg}
    end

You can copy the implementation above or define your own that converts the arguments given to GenServer.start_link/3 to the server state.

  mygenserver.exs:1: MyGenServer (module)

```

Writing this documentation is easy if all I have to do is copy the output from elixir, but maybe some highlights:

`We will inject a default implementation` is a result of the `use` macro. Well quite obvious considering that's all in our module, but this is because the use macro allows that module to inject any code in the current module.

other than that, nothing is said of the API side which you will see most of the times (or is actually required). Let us refactor this:

```elixir
defmodule MyGenServer do
  use GenServer

  ##########
  #  API   #
  ##########
  def start(args), do: GenServer.start(__MODULE__, args, name: __MODULE__)
  def start_link(args), do: GenServer.start_link(__MODULE__, args, name: __MODULE__)

  ##########
  # SERVER #
  ##########
  def init(init_arg), do: {:ok, init_arg}
end
```

Wonderful. Compiling this doesn't throw any warnings or errors anymore. But what does this code do?
 * `start/1` starts the genserver without linking it to the current process. You don't do this often, considering you most likely want to link this to a supervisor. Hence we also provide a `start_link/1`, but during this demo I'll use `start/1` so that my shell doesn't crash.
 * We can now call `MyGenServer.start(_link)/1` and `GenServer.start/3` is executed. It takes 3 arguments: 
   * The first one being its module. This is because the `init/1` function will be called after this on the specified module, as the warning already indicated. **Note: this function does not return until the init function has finished! If you do too much heavy work here, your supervisor will start its childs very slowly (more about this later). For heavy work, use the handle_continue callback**
   * the second being the `init/1` function, more about this later.
   * the third one being the options. Here you can configure the name registration, garbage collector, etc... A complete list can be found at https://hexdocs.pm/elixir/GenServer.html#t:option/0

#### Watch out with the `init/1` callback
Let`s first see an example with basic argument passing:

```elixir
defmodule MyGenServer do
  use GenServer
  require IEx
  def start_link(args), do: GenServer.start_link(__MODULE__, args, name: __MODULE__)
  def init(args), do: IEx.pry()
end

args_to_be_passed = [a: :value, b: :another_value]
MyGenServer.start_link(args_to_be_passed)
```

_Note: you can "pry" into a process with the IEx module. Keep in mind that you have to require it first. `require` is a macro. when calling this with `iex -r mygenserver.exs`, you will see the following message:_

```elixir
> $ iex mygenserver.exs
Request to pry #PID<0.109.0> at MyGenServer.init/1 (mygenserver.exs:20)

   18:   require IEx
   19:   def start_link(args), do: GenServer.start_link(__MODULE__, args, name: __MODULE__)
   20:   def init(args), do: IEx.pry()
   21: end
   22: 

Allow? [Yn] 
Interactive Elixir (1.9.1) - press Ctrl+C to exit (type h() ENTER for help)
pry(1)> args
[a: :value, b: :another_value]
```

Here you can see that the args have been passed automatically into the `init/1` function. This should normally reply one of the responses listed in this url: https://hexdocs.pm/elixir/GenServer.html#c:init/1 , but most likely you'll return something like `{:ok, state}` where state is a variable.

### Structs
Structs are basically fancy maps which allow compile-time checks and default values. We'll use it to define our limit of tasks that can be active at the time in our basic task handler.

Defining a struct for your module is done with `defstruct`. When you use a combination of default values and implicit nil values, you must first specify the fields which implicitly default to nil.

```elixir
defmodule TaskHandler do
  use GenServer

  defstruct task_limit: 2, tasks: []

  def start_link(args), do: GenServer.start_link(__MODULE__, args, name: __MODULE__)
  def init(_args), do: {:ok, %TaskHandler{}}
end
```

In the above example, you can see that the defstruct has several default values which will be used as your state. Keep in mind that the arguments provided are ignored in this case.

Adding `@enforce_keys` will enforce giving necessary parameters to create your struct. A possible implementation could be:

```elixir
defmodule TaskHandler do
  use GenServer

  defmodule TaskHandler.State do
    @enforce_keys [:task_limit]
    defstruct [:task_limit, tasks: []]
  end

  def start_link(args), do: GenServer.start_link(__MODULE__, args, name: __MODULE__)
  def init(args), do: {:ok, struct!(TaskHandler.State, args)}
end
```
But we're not going to work with key enforcing, just default values. This means we can simplify it to:
```elixir
defmodule TaskHandler do
  use GenServer

  defstruct task_limit: 2, tasks: []

  def start_link(args \\ []), do: GenServer.start_link(__MODULE__, args, name: __MODULE__)
  def init(args), do: {:ok, struct(TaskHandler, args)}
end
```
Calling `Process.whereis TaskHandler` will find our running pid, now we can finally get started.

### handle continue

Later on we'll see the complete implementation of this GenServer, but for now we'll just focus on the handle continue callback. As already mentioned before, we don't want to do long/expensive operations in our `init` function. That's why there is a handle continue callback, which assures that this is the first message in the mailbox. A simple example:

```elixir
defmodule TaskHandler do
  use GenServer
  defstruct task_limit: 2, tasks: [], queue: []

  def start_link(args \\ []), do: GenServer.start_link(__MODULE__, args, name: __MODULE__)

  def init(args), do: {:ok, struct(TaskHandler, args), {:continue, :start_recurring_tasks}}

  def handle_continue(:start_recurring_tasks, state) do
    send(self(), :check_tasks)
    {:noreply, state}
  end
end
```

In the `init/1` callback you can see that instead of just saying `{:ok, state}`, we return a 3 element tuple with `{:continue, :start_recurring_tasks}`. This assures that the first message in the mailbox, after the GenServer process is alive, is `:start_recurring_tasks` which needs to be handled with `handle_info`. In this case, we'll use it to send periodic "checks".

### handle info
We've now got a GenServer with a message that can't be handled. If we don't specify this handle_info, then our GenServer will crash. Let us implement this now:

```elixir
  def handle_info(:check_tasks, %{tasks: t, queue: []} = s) do
    {alive, _fin} = Enum.split_with(t, fn pid -> Process.alive?(pid) end)
    Process.send_after(self(), :check_tasks, @check_time)
    {:noreply, %{s | tasks: alive}}
  end

  def handle_info(:check_tasks, %{tasks: t, queue: [first_fun | rest]} = s) do
    Process.send_after(self(), :check_tasks, @check_time)

    Enum.split_with(t, fn pid -> Process.alive?(pid) end)
    |> case do
      {_, []} -> {:noreply, s}
      {alive, _fin} -> {:noreply, %{s | tasks: [spawn(first_fun) | alive], queue: rest}}
    end
  end
```

Note that we're using multi-clause functions for the same message. The `handle_info/2` has 2 parameters. The first is simply the message, quite obvious. The second one is the state that we defined in our `init/1` function. 

So what does this code do? Let us start with the first function clause, the one where our queue is empty.
_To provide some extra information: This is just a GenServer which will keep a list of spawned pids (which are not linked to this process!)._

First of all we check that the queue is empty. Though we do assign the list of spawned pids to `t`, which is a list. After that we'll filter the dead tasks out of it (for now we don't mind about values which could be collected, like with Tasks, or any other kind of response values like `EXIT` or `DOWN` messages). 

```elixir
{alive, _fin} = Enum.split_with(t, fn pid -> Process.alive?(pid) end)
```

Long story short, all the alive processes are in the alive variable and finished "tasks", or more accurately processes in this case, are ignored. After that we update the state with the alive tasks. Note that somewhere 