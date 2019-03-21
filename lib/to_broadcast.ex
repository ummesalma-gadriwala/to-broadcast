defmodule TOBroadcast do
    # names of participants
    def start(name, participants) do
        # IO.inspect self()
        state = %{
            me: name, # string
            ppid: self(), # pid
            participants: participants, # list[strings]
            # pending: %{"p1": [], "p2": [], ..., "pn": []}
            pending: for participant <- participants, into: %{} do
                        {participant, []}
                     end,
            # Create ts map for participants
            # pending: {"p1": 0, "p2": 0, ..., "pn": 0}
            ts: for participant <- participants, into: %{} do
                    {participant, 0}
                end
        }
        # spawns process p that executes run
        pid = spawn(TOBroadcast, :run, [state])
        # p tracks of name, parent PID, list of participant names in local state
        # return: p's pid
        # register name in process registry
        :global.register_name(name, pid)
        pid
    end

    def bc_send(msg, origin) do
        # initiates broadcast of msg by pi with name origin to all participants
        # sends {:input, :bc_initiate, msg} to pi to simulate receiving an input from above layer
        pid = :global.whereis_name(origin)
        send(pid, {:input, :bc_initiate, msg})
    end

    def run(state) do       
        state = 
        receive do
            {:input, :bc_initiate, msg} ->
                # ts[i]++
                state = update_in(state, 
                                  [:ts, state.me],
                                  fn(t) -> t+1 end )
                me = state.me
                tsAti = state.ts[me]
                
                state = update_in(state, 
                                  [:pending, state.me],
                                  fn msgList -> msgList ++ [{msg, tsAti, state.me}] end)
                for participant <- state.participants do
                    # participant here is a string, will this work?
                    # string to atom required?
                    pid = :global.whereis_name(participant)
                    send(pid, {:bc_msg, msg, tsAti, state.me})
                end
                # IO.puts "state after input:"
                # IO.inspect state
                state
            
            {:ts_up, t, origin_name} ->
                # timestamp update message originating from origin_name
                # ts[j] = T
                cond do
                    origin_name == state.me -> state
                    origin_name != state.me ->
                        state = update_in(state, 
                                  [:ts, origin_name],
                                  fn(_) -> t end )
                        # IO.puts "state after ts_up:"
                        # IO.inspect state
                        state
                end
                
            {:bc_msg, msg, t, origin_name} ->
                # IO.puts "in bc msg"
                # broadcast message carrying msg, timestamp from origin_name
                cond do
                    origin_name == state.me -> 
                        # IO.puts "here?"
                        state
                    origin_name != state.me ->
                        # ts[j] = T
                        state = update_in(state, 
                                        [:ts, origin_name],
                                        fn(_) -> t end )

                        state = update_in(state, 
                                        [:pending, origin_name],
                                        fn msgList -> msgList ++ [{msg, t, origin_name}] end)
                        tsAti = state.ts[state.me]
                        state =             
                        if t > tsAti do
                            # ts[i] = T
                            state =
                            update_in(state, 
                                        [:ts, state.me],
                                        fn(_) -> t end )
                            for participant <- state.participants do
                                pid = :global.whereis_name(participant)
                                send(pid, {:ts_up, t, state.me})
                            end
                            state
                        else 
                            state
                        end
                        # IO.puts "state after bc_msg:"
                        # IO.inspect state
                        state
                end
                
            {:output, :to_bcast_rcvd, msg, origin} -> 
                IO.puts "To: #{inspect state.me} From: #{inspect origin}, Message: #{inspect elem(msg,0)}"
                # IO.puts "state after output:"
                state
        end

        # IO.inspect state
        ready = ready_messages(state.pending, state.participants)
        # IO.inspect ready
        # Find smallest timestamp in state.ts
        allTs = Map.values(state.ts)
        sortedTs = Enum.sort(allTs, &(&1 <= &2))
        minimumT = List.first(sortedTs)
        # IO.inspect minimumT
        good = good_messages(ready, minimumT)
        # IO.inspect good
        state = remove_pending(good, state)
        # IO.inspect state
        # send_good(good, self())
        send_good(good, state.ppid)

        run(state)
        
    end

    # Gets msg with smallest ts for each process from pending
    def ready_messages(_, []), do: []
    def ready_messages(pending, [participant | participants]) do
        msgList = pending[participant]
        sortedList = Enum.sort(msgList, &(elem(&1, 1) <= elem(&2, 1)))
        cond do
            List.first(sortedList) == nil -> ready_messages(pending, participants)
            List.first(sortedList) != nil -> [List.first(sortedList)] ++ ready_messages(pending, participants)
        end
    end

    # Gets msgs with ts <= ts[k] for all k
    def good_messages([], _), do: []
    def good_messages([msg | msgs], t) do
        msgT = elem(msg, 1)
        if msgT <= t do
            [msg] ++ good_messages(msgs, t)
        else
            good_messages(msgs, t)
        end
        
    end

    # Gets msgs with ts <= ts[k] for all k
    def remove_pending([], state), do: state
    def remove_pending([msg | msgs], state) do
        origin_name = elem(msg, 2)
        newState = update_in(state, 
                            [:pending, origin_name],
                            fn msgList -> msgList -- [msg] end)
        Map.merge(newState, remove_pending(msgs, newState))
    end

    def send_good([], _) do
    end
    def send_good([msg | msgs], ppid) do
        # IO.inspect "sending messages"
        origin = elem(msg, 2)
        send(ppid, {:output, :to_bcast_rcvd, msg, origin})
        send_good(msgs, ppid)
    end
end


p1 = TOBroadcast.start("p1", ["p1","p2","p3","p4"])
p2 = TOBroadcast.start("p2", ["p1","p2","p3","p4"])
p3 = TOBroadcast.start("p3", ["p1","p2","p3","p4"])
p4 = TOBroadcast.start("p4", ["p1","p2","p3","p4"])
TOBroadcast.bc_send("Hello World!","p2")
:timer.sleep(200)
TOBroadcast.bc_send("Hello World!","p3")
:timer.sleep(200)
TOBroadcast.bc_send("Hello World again!","p2")
:timer.sleep(200)
TOBroadcast.bc_send("Hello World!","p1")