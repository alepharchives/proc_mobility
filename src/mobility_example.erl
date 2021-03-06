%%% -------------------------------------------------------------------
%%% Author  : michal
%%% Description :
%%%
%%% Created : 26-04-2012
%%% -------------------------------------------------------------------
-module(mobility_example).

-behaviour(gen_server).
-behaviour(mobile_proc).
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include("proc_mobility.hrl").
-include("proc_logging.hrl").
%% --------------------------------------------------------------------
%% External exports
-export([]).

%% mobile_proc callbacks
-export([init_state/1, send_me/1, register/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).


-export([start/0]).

-record(state, {pings=0,msgs=0,casts=0}).

%% ====================================================================
%% External functions
%% ====================================================================

start() ->
	Status = gen_server:start({local, ?MODULE}, ?MODULE, [], []),
	spawn(fun() -> pinger() end),
	register(),
	Status.

start_with_state(State) ->
	gen_server:start({local, ?MODULE}, ?MODULE, {mobility, State}, []).

%% ====================================================================
%% Mobile Proc functions
%% ====================================================================

init_state(State) ->
	{ok, _Pid} = start_with_state(State),
	ok.
	

send_me(Destination) ->
    Pid = proc_mobility:whereis_name(?MODULE),
    gen_server:call(?MODULE, {mobility, send_me, Destination}).

register() ->
	gen_server:call(?MODULE, {mobility, register}).

get_code() ->
	[code:get_object_code(?MODULE)].
%% ====================================================================
%% Server functions
%% ====================================================================

%% --------------------------------------------------------------------
%% Function: init/1
%% Description: Initiates the server
%% Returns: {ok, State}          |
%%          {ok, State, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%% --------------------------------------------------------------------
init([]) ->
	?INFO_MSG("Starting"),
    {ok, #state{}};

init({mobility, State}) ->
	?INFO_MSG("Init with state ~p", [State]),
	{ok, State}.
%% --------------------------------------------------------------------
%% Function: handle_call/3
%% Description: Handling call messages
%% Returns: {reply, Reply, State}          |
%%          {reply, Reply, State, Timeout} |
%%          {noreply, State}               |
%%          {noreply, State, Timeout}      |
%%          {stop, Reason, Reply, State}   | (terminate/2 is called)
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------

handle_call({mobility, send_me, Destination}, _From, State) ->
	case proc_mobility:migrate(#mproc_state{name=?MODULE, module=?MODULE, state=State, code=[]}, Destination) of
		ok ->
			{stop, normal, ok, State};
		Result -> 
			{reply, Result, State}
	end;

handle_call({mobility, register}, _From, State) ->
	Reply = proc_mobility:register_name(?MODULE, self()),
	{reply, Reply, State};

handle_call(ping, _From, State) ->
	%%?INFO_MSG("ping number ~p", [State#state.pings]),
	{reply, pong, State#state{pings=(State#state.pings + 1)}};

handle_call(_Request, _From, State) ->
	?INFO_MSG("Unknown request ~p from ~p~n", [_Request, _From]),
    Reply = unknown,
    {reply, Reply, State}.

%% --------------------------------------------------------------------
%% Function: handle_cast/2
%% Description: Handling cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
handle_cast(_Msg, State) ->
	?INFO_MSG("got cast request number ~p",[State#state.casts]),
    {noreply, State#state{casts=State#state.casts+1}}.

%% --------------------------------------------------------------------
%% Function: handle_info/2
%% Description: Handling all non call/cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
handle_info(Info, State) ->
	?INFO_MSG("got info ~p, number ~p", [Info, State#state.msgs]),
    {noreply, State#state{msgs=State#state.msgs+1}}.

%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(Reason, State) ->
	?INFO_MSG("proces terminated with reason ~p and state ~p", [Reason, State]),
    ok.

%% --------------------------------------------------------------------
%% Func: code_change/3
%% Purpose: Convert process state when code is changed
%% Returns: {ok, NewState}
%% --------------------------------------------------------------------
code_change(OldVsn, State, Extra) ->
    {ok, State}.

%% --------------------------------------------------------------------
%%% Internal functions
%% --------------------------------------------------------------------

pinger() ->
	receive
		after 5000 -> 
			%%io:format("sending ping to ~p~n", [?MODULE]),
			gen_server:call({via, proc_mobility, ?MODULE}, ping)
%% 			timer:sleep(1000),
%% 			gen_server:cast({via, proc_mobility, ?MODULE}, ping_cast),
%% 			timer:sleep(1000),
%% 			proc_mobility:whereis_name(?MODULE) ! ping_info 
	end,
	pinger().
