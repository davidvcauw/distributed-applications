GenServers. Now the fun begins!

At the end of these exercises, we're going to have a tracking application for people in a building (of course, this is just a fictional exercise and by no means would we dare to violate privacy rights). 

First step: Create a GenServer process that simulates the state of a building. Use `defstruct` to make sure that you can start the GenServer without providing arguments. The GenServer should be:
 * Name registered with the name of the building. For now we'll assume that these are unique (Hint: https://www.amberbit.com/blog/2016/5/13/process-name-registration-in-elixir/)
 * What __rooms__ are available (with their __capacity__), you can hardcode these in your struct in the beginning. Modifying state is not the purpose of this exercise.

I want to be able to call `MyBuilding.get_rooms_for_building(ProximusBlokD)`, which should return an appropriate data structure.