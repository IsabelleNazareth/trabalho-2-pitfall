
:-dynamic posicao/3.
:-dynamic ultima_pos/2.
:-dynamic memory/3.
:-dynamic visitado/2.
:-dynamic certeza/2.
:-dynamic sem_saida/2.
:-dynamic visita_count/3.
:-dynamic energia/1.
:-dynamic pontuacao/1.
:-dynamic collected/2.
:-dynamic local_sensacao/3.

:-consult('mapa-dificil.pl').

delete([], _, []).
delete([Elem|Tail], Del, Result) :-
    (   \+ Elem \= Del
    ->  delete(Tail, Del, Result)
    ;   Result = [Elem|Rest],
        delete(Tail, Del, Rest)
    ).

% remove primeira ocorrência de um elemento (usada em limpeza de sensores)
delete_elem(Elem, [Elem|T], T) :- !.
delete_elem(Elem, [H|T], [H|R]) :- delete_elem(Elem, T, R).
delete_elem(_, [], []).
	


reset_game :- retractall(memory(_,_,_)), 
			retractall(visitado(_,_)), 
			retractall(certeza(_,_)),
			retractall(sem_saida(_,_)),
			retractall(visita_count(_,_,_)),
			retractall(energia(_)),
			retractall(pontuacao(_)),
			retractall(posicao(_,_,_)),
			retractall(ultima_pos(_,_)),
			retractall(collected(_,_)),
			retractall(local_sensacao(_,_,_)),
			assert(energia(100)),
			assert(pontuacao(0)),
			assert(posicao(1,1, norte)),
			assert(ultima_pos(1,1)),
			assert(visitado(1,1)).


:-reset_game.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Controle de Status
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%atualiza pontuacao
atualiza_pontuacao(X):- pontuacao(P), retract(pontuacao(P)), NP is P + X, assert(pontuacao(NP)),!.

%atualiza energia
atualiza_energia(N):- energia(E), retract(energia(E)), NE is E + N, 
					(
					 (NE =<0, assert(energia(0)),posicao(X,Y,_),retract(posicao(_,_,_)), assert(posicao(X,Y,morto)),!);
					 (NE >100, assert(energia(100)),!);
					  (NE >0,assert(energia(NE)),!)
					 ).


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% LÓGICA DE INFERÊNCIA AVANÇADA (DETETIVE)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Auxiliar: Lugar conhecido é onde já fui OU onde estou agora
conhecido(X, Y) :- visitado(X, Y).
conhecido(X, Y) :- posicao(X, Y, _).

% Vizinho Estático
vizinho_de(X, Y, NX, NY) :- NX is X, NY is Y + 1, map_size(_,H), NY =< H.
vizinho_de(X, Y, NX, NY) :- NX is X, NY is Y - 1, NY > 0.
vizinho_de(X, Y, NX, NY) :- NX is X + 1, NY is Y, map_size(W,_), NX =< W.
vizinho_de(X, Y, NX, NY) :- NX is X - 1, NY is Y, NX > 0.

% Candidatos ainda desconhecidos ao redor de uma fonte de sensor
candidatos_sensor(X, Y, Lista) :-
    findall((NX, NY), (
        vizinho_de(X, Y, NX, NY),
        \+ visitado(NX, NY),
        \+ certeza(NX, NY)
    ), Lista).

sensacao_explicada(Sensor, SX, SY) :-
    vizinho_de(SX, SY, NX, NY),
    certeza(NX, NY),
    memory(NX, NY, M),
    member(Sensor, M).

% Regra Genérica: Tenta triangular perigos (busca pares de casas que sentiram o mesmo sensor)
triangulacao :-
    (tenta_triangular(passos); true),
    (tenta_triangular(palmas); true),
    (tenta_triangular(brisa); true), !.

% Procura pares distintos de casas com o mesmo sensor e cruza seus vizinhos
tenta_triangular(Sensor) :-
    % posições onde o sensor foi sentido
    findall((X,Y), (
        local_sensacao(X, Y, Sens),
        member(Sensor, Sens),
        \+ sensacao_explicada(Sensor, X, Y)   % ignora fontes já explicadas por perigo certo
    ), Fontes0),
    sort(Fontes0, Fontes),                  % remove duplicados
    member((X1,Y1), Fontes),
    member((X2,Y2), Fontes),
    (X1 \= X2 ; Y1 \= Y2),                  % garante casas diferentes

    % candidatos por sensor (apenas ainda desconhecidos)
    candidatos_sensor(X1, Y1, C1),
    candidatos_sensor(X2, Y2, C2),

    % só triangula quando cada fonte tem apenas um candidato E eles coincidem
    C1 = [(TargetX, TargetY)],
    C2 = [(TargetX, TargetY)],

    % confirma perigo
    retractall(memory(TargetX, TargetY, _)),
    assert(memory(TargetX, TargetY, [Sensor])),
    assert(certeza(TargetX, TargetY)),
    write('DETETIVE: CONFIRMADO '), write(Sensor), write(' EM '), write(TargetX), write(','), writeln(TargetY).

% --- CONTADORES INTELIGENTES ---
total_inimigos(4).
total_pocos(8).
total_teleportes(4).

% --- AUXILIARES ---
ouros_restantes(N) :- 
    findall(1, tile(_,_, 'O'), Lista), 
    length(Lista, N).

inimigos_encontrados(N) :-
    findall((X,Y), (
        (visitado(X,Y), (tile(X,Y,'D'); tile(X,Y,'d')));
        (certeza(X,Y), memory(X,Y,M), member(passos, M), \+ visitado(X,Y))
    ), Lista),
    sort(Lista, Unicos), length(Unicos, N).

pocos_encontrados(N) :-
    findall((X,Y), (
        (conhecido(X,Y), tile(X,Y,'P'));
        (certeza(X,Y), memory(X,Y,M), member(brisa, M), \+ conhecido(X,Y))
    ), Lista),
    sort(Lista, Unicos), length(Unicos, N).

teleportes_encontrados(N) :-
    findall((X,Y), (
        (conhecido(X,Y), tile(X,Y,'T'));
        (certeza(X,Y), memory(X,Y,M), member(palmas, M), \+ conhecido(X,Y))
    ), Lista),
    sort(Lista, Unicos), length(Unicos, N).

apagar_suspeitas(Sensor) :-
    memory(X, Y, Mem), member(Sensor, Mem), 
	\+ certeza(X, Y),\+ conhecido(X,Y), %\+ visitado(X,Y),
    delete(Mem, Sensor, NovaMem),
    retract(memory(X, Y, Mem)), assert(memory(X, Y, NovaMem)),
    write('LIMPEZA: Removido suspeita de '), write(Sensor), write(' em '), write(X), write(','), writeln(Y),
    fail.
apagar_suspeitas(_) :- true.

%Limpeza Global: Se achou todos de um tipo, apaga as suspeitas restantes
limpeza_global :-
    total_inimigos(TI), inimigos_encontrados(IE), IE >= TI, apagar_suspeitas(passos);
    total_pocos(TP), pocos_encontrados(PE), PE >= TP, apagar_suspeitas(brisa);
    total_teleportes(TT), teleportes_encontrados(TE), TE >= TT, apagar_suspeitas(palmas);
    true.

reportar_status :-
    total_inimigos(TI), inimigos_encontrados(IE), RestoI is TI - IE,
    total_pocos(TP), pocos_encontrados(PE), RestoP is TP - PE,

    nl, write('--- STATUS DO CONHECIMENTO ---'), nl,
    write('Inimigos Restantes: '), write(RestoI), write('/'), write(TI), nl,
	write('Pocos Restantes: '), write(RestoP), write('/'), write(TP), nl.



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Verifica Eventos na Posição
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%Ouro: Marca como coletado, ganha pontos, mas NAO deleta tile ainda (visual)
%    Ganha pontos, marca como coletado, mas NÃO deleta o tile ainda.
verifica_player :- 
    posicao(X,Y,_), tile(X,Y,'O'), 
    \+ collected(X,Y),          % Verifica se já não pegamos esse ouro
    assert(collected(X,Y)),     % Marca como pego
    atualiza_pontuacao(1000),   % Ganha pontos
    % set_real(X,Y),            
    fail.                       

%PowerUp: Marca como coletado se energia < 100
verifica_player :- 
    posicao(X,Y,_), tile(X,Y,'U'), 
    \+ collected(X,Y),      
    energia(E), E < 100,    % Só pega se precisar!
    assert(collected(X,Y)), % Marca como pego
    atualiza_energia(20),   % Cura
    fail.                   

%Buracos
verifica_player :- posicao(X,Y,_), tile(X,Y,'P'), atualiza_energia(-100), atualiza_pontuacao(-1000),!.
%Inimigos
verifica_player :- posicao(X,Y,_), tile(X,Y,'D'), atualiza_energia(-50),!.
verifica_player :- posicao(X,Y,_), tile(X,Y,'d'), atualiza_energia(-20),!.
%Teleporte
verifica_player :- posicao(X,Y,Z), tile(X,Y,'T'), 
					map_size(SX,SY), random_between(1,SX,NX), random_between(1,SY,NY),
				retract(posicao(X,Y,Z)), assert(posicao(NX,NY,Z)), 
				((retract(visitado(NX,NY)), assert(visitado(NX,NY))); assert(visitado(NX,NY))),
				set_real(NX,NY),
				atualiza_obs, verifica_player,!.
verifica_player :- true.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Comandos
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%virar direita
virar_direita :- posicao(X,Y, norte), retract(posicao(_,_,_)), assert(posicao(X, Y, leste)),atualiza_pontuacao(-1),!.
virar_direita :- posicao(X,Y, oeste), retract(posicao(_,_,_)), assert(posicao(X, Y, norte)),atualiza_pontuacao(-1),!.
virar_direita :- posicao(X,Y, sul), retract(posicao(_,_,_)), assert(posicao(X, Y, oeste)),atualiza_pontuacao(-1),!.
virar_direita :- posicao(X,Y, leste), retract(posicao(_,_,_)), assert(posicao(X, Y, sul)),atualiza_pontuacao(-1),!.

%virar esquerda
virar_esquerda :- posicao(X,Y, norte), retract(posicao(_,_,_)), assert(posicao(X, Y, oeste)),atualiza_pontuacao(-1),!.
virar_esquerda :- posicao(X,Y, oeste), retract(posicao(_,_,_)), assert(posicao(X, Y, sul)),atualiza_pontuacao(-1),!.
virar_esquerda :- posicao(X,Y, sul), retract(posicao(_,_,_)), assert(posicao(X, Y, leste)),atualiza_pontuacao(-1),!.
virar_esquerda :- posicao(X,Y, leste), retract(posicao(_,_,_)), assert(posicao(X, Y, norte)),atualiza_pontuacao(-1),!.

%Limpa o item do mapa somente quando o agente SAI da casa
limpar_rastro(X,Y) :- 
    collected(X,Y), tile(X,Y,Z), (Z='O'; Z='U'),
    retract(tile(X,Y,Z)), assert(tile(X,Y,'')), set_real(X,Y), !.
limpar_rastro(_,_).

incrementa_visita(X, Y) :-
    (   visita_count(X, Y, N) -> N1 is N + 1, retract(visita_count(X, Y, N))
    ;   N1 = 1),
    assert(visita_count(X, Y, N1)),
    (N1 >= 3, X \= 1, Y \= 1 -> assert(sem_saida(X, Y)); true).

%andar
andar :- posicao(X,Y,P), P = norte, map_size(_,MAX_Y), Y < MAX_Y, YY is Y + 1,
		 limpar_rastro(X,Y), % Limpa o ouro ao sair
         retract(posicao(X,Y,_)), assert(posicao(X, YY, P)), 
		 retractall(ultima_pos(_,_)), assert(ultima_pos(X,Y)),
		 set_real(X,YY),
		 incrementa_visita(X,YY),
		 ((retract(visitado(X,Y)), assert(visitado(X,Y))); assert(visitado(X,Y))),atualiza_pontuacao(-1),!.
		 
andar :- posicao(X,Y,P), P = sul,  Y > 1, YY is Y - 1, 
		 limpar_rastro(X,Y), % Limpa o ouro ao sair
         retract(posicao(X,Y,_)), assert(posicao(X, YY, P)), 
		 retractall(ultima_pos(_,_)), assert(ultima_pos(X,Y)),
		 set_real(X,YY),
		 incrementa_visita(X,YY),
		 ((retract(visitado(X,Y)), assert(visitado(X,Y))); assert(visitado(X,Y))),atualiza_pontuacao(-1),!.

andar :- posicao(X,Y,P), P = leste, map_size(MAX_X,_), X < MAX_X, XX is X + 1, 
		 limpar_rastro(X,Y), % Limpa o ouro ao sair
         retract(posicao(X,Y,_)), assert(posicao(XX, Y, P)), 
		 retractall(ultima_pos(_,_)), assert(ultima_pos(X,Y)),
		 set_real(XX,Y),
		 incrementa_visita(XX,Y),
		 ((retract(visitado(X,Y)), assert(visitado(X,Y))); assert(visitado(X,Y))),atualiza_pontuacao(-1),!.

andar :- posicao(X,Y,P), P = oeste,  X > 1, XX is X - 1, 
		 limpar_rastro(X,Y), % Limpa o ouro ao sair
         retract(posicao(X,Y,_)), assert(posicao(XX, Y, P)), 
		 retractall(ultima_pos(_,_)), assert(ultima_pos(X,Y)),
		 set_real(XX,Y),
		 incrementa_visita(XX,Y),
		 ((retract(visitado(X,Y)), assert(visitado(X,Y))); assert(visitado(X,Y))),atualiza_pontuacao(-1),!.
		 
%pegar	
pegar :- posicao(X,Y,_), tile(X,Y,'O'), retract(tile(X,Y,'O')), assert(tile(X,Y,'')), atualiza_pontuacao(-5), atualiza_pontuacao(500),set_real(X,Y),!. 
pegar :- posicao(X,Y,_), tile(X,Y,'U'), retract(tile(X,Y,'U')), assert(tile(X,Y,'')), atualiza_pontuacao(-5), atualiza_energia(50),set_real(X,Y),!. 
pegar :- atualiza_pontuacao(-5),!.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Controle automático de ações
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

perigo_marcado(M) :- member(brisa, M).
perigo_marcado(M) :- member(passos, M).
perigo_marcado(M) :- member(palmas, M).

seguro(X, Y) :- certeza(X, Y), memory(X, Y, M), \+ perigo_marcado(M).
seguro(X, Y) :- visitado(X, Y). % visitado já implica ter sido seguro

adjacente_seguro_nao_visitado(X, Y) :-
    posicao(PX, PY, _),
    vizinho_de(PX, PY, X, Y),
    seguro(X, Y),
    \+ visitado(X, Y).

% Lista todas as casas seguras ainda não visitadas
fronteiras_seguras(Lista) :-
    findall((X,Y), (seguro(X,Y), \+ visitado(X,Y)), Lista).

% Verifica se uma casa visitada tem fronteira segura não visitada
visitado_com_fronteira(X, Y) :-
    visitado(X, Y),
    vizinho_de(X, Y, NX, NY),
    seguro(NX, NY),
    \+ visitado(NX, NY).

fronteira_segura(Lista) :-
    findall((X,Y), adjacente_seguro_nao_visitado(X,Y), Lista).

% Distância Manhattan entre dois pontos
dist_manhattan(X1, Y1, X2, Y2, D) :-
    DX is abs(X1 - X2),
    DY is abs(Y1 - Y2),
    D is DX + DY.

% Menor distância de (X,Y) até qualquer casa em Lista
distancia_ate_lista(X, Y, Lista, DMin) :-
    findall(D, (member((LX,LY), Lista), dist_manhattan(X, Y, LX, LY, D)), Ds),
    Ds \= [],
    min_list(Ds, DMin).

% Melhor visitado que leva mais perto de uma fronteira segura; se não houver, base
proximo_destino(X, Y) :-
    fronteiras_seguras(F), F \= [],
    findall((D, VX, VY), (visitado(VX, VY), \+ sem_saida(VX, VY), distancia_ate_lista(VX, VY, F, D)), Lista),
    Lista \= [],
    sort(Lista, [(_, X, Y)|_]), !.
proximo_destino(1, 1).

% Passo seguro que reduz a distancia até o destino
passo_destino(TX, TY, NX, NY, Dir) :-
    posicao(PX, PY, _),
    dist_manhattan(PX, PY, TX, TY, D0),
    vizinho_de(PX, PY, NX, NY),
    seguro(NX, NY),
    dist_manhattan(NX, NY, TX, TY, D1),
    D1 < D0,
    direcao_para(NX, NY, Dir).

% BFS em áreas seguras para achar o próximo passo até o destino
caminho_seguro(TX, TY, Dir) :-
    posicao(PX, PY, _),
    bfs_seguro([(PX, PY, [])], [], (TX, TY), Caminho),
    Caminho = [(NX, NY)|_],
    direcao_para(NX, NY, Dir).

bfs_seguro([], _, _, _) :- fail.
bfs_seguro([(X, Y, Path)|_], _, (X, Y), Path) :- !.
bfs_seguro([(X, Y, Path)|Rest], Visitados, Dest, Resultado) :-
    findall((NX, NY, NovoPath), (
        vizinho_de(X, Y, NX, NY),
        seguro(NX, NY),
        \+ member((NX, NY), Visitados),
        \+ member((NX, NY), Path),
        append(Path, [(NX, NY)], NovoPath)
    ), Sucessores),
    append(Rest, Sucessores, Fila),
    bfs_seguro(Fila, [(X, Y)|Visitados], Dest, Resultado).

% BFS para qualquer fronteira segura disponível (evita alvos inalcançáveis)
caminho_seguro_fronteira(TX, TY, Dir) :-
    fronteiras_seguras(F), F \= [],
    posicao(PX, PY, _),
    bfs_seguro_multi([(PX, PY, [])], [], F, (TX, TY), Caminho),
    Caminho = [(NX, NY)|_],
    direcao_para(NX, NY, Dir).

bfs_seguro_multi([], _, _, _, _) :- fail.
bfs_seguro_multi([(X, Y, Path)|_], _, Goals, (X, Y), Path) :-
    member((X, Y), Goals), !.
bfs_seguro_multi([(X, Y, Path)|Rest], Visitados, Goals, Dest, Resultado) :-
    findall((NX, NY, NovoPath), (
        vizinho_de(X, Y, NX, NY),
        seguro(NX, NY),
        \+ member((NX, NY), Visitados),
        \+ member((NX, NY), Path),
        append(Path, [(NX, NY)], NovoPath)
    ), Sucessores),
    append(Rest, Sucessores, Fila),
    bfs_seguro_multi(Fila, [(X, Y)|Visitados], Goals, Dest, Resultado).

% BFS em casas visitadas para voltar à base
caminho_base_seguro(Dir) :-
    posicao(PX, PY, _),
    bfs_visitado([(PX, PY, [])], [], (1, 1), Caminho),
    Caminho = [(NX, NY)|_],
    direcao_para(NX, NY, Dir).

bfs_visitado([], _, _, _) :- fail.
bfs_visitado([(X, Y, Path)|_], _, (X, Y), Path) :- !.
bfs_visitado([(X, Y, Path)|Rest], Visitados, Dest, Resultado) :-
    findall((NX, NY, NovoPath), (
        vizinho_de(X, Y, NX, NY),
        visitado(NX, NY),
        \+ member((NX, NY), Visitados),
        \+ member((NX, NY), Path),
        append(Path, [(NX, NY)], NovoPath)
    ), Sucessores),
    append(Rest, Sucessores, Fila),
    bfs_visitado(Fila, [(X, Y)|Visitados], Dest, Resultado).

adjacente_visitado(X, Y) :-
    posicao(PX, PY, _),
    vizinho_de(PX, PY, X, Y),
    visitado(X, Y).

distancia_base(X, Y, D) :-
    DX is abs(X - 1),
    DY is abs(Y - 1),
    D is DX + DY.

melhor_retorno_base(X, Y) :-
    posicao(PX, PY, _),
    findall((D, NX, NY), (vizinho_de(PX, PY, NX, NY), visitado(NX, NY), distancia_base(NX, NY, D)), Lista),
    sort(Lista, Ordenada),
    Ordenada = [(_, X, Y)|_].

melhor_visitado_para_explorar(X, Y) :-
    posicao(PX, PY, _),
    findall((NX, NY), (vizinho_de(PX, PY, NX, NY), visitado_com_fronteira(NX, NY)), Fronteiras),
    Fronteiras \= [],
    Fronteiras = [(X, Y)|_], !. % prioriza vizinho que leva a fronteira segura

melhor_visitado_para_explorar(X, Y) :-
    posicao(PX, PY, _),
    findall((NX, NY), (vizinho_de(PX, PY, NX, NY), visitado(NX, NY)), Lista0),
    ultima_pos(LX, LY),
    exclude(=( (LX, LY) ), Lista0, Lista), % tenta evitar voltar imediatamente
    ( Lista = [(X, Y)|_]
    ; (Lista = [], Lista0 = [(X,Y)|_]) % se não houver outra opção, volta
    ).

direcao_para(X, _, leste) :- posicao(PX, _, _), X > PX, !.
direcao_para(X, _, oeste) :- posicao(PX, _, _), X < PX, !.
direcao_para(_, Y, norte) :- posicao(_, PY, _), Y > PY, !.
direcao_para(_, Y, sul) :- posicao(_, PY, _), Y < PY, !.

dir_direita(norte, leste).
dir_direita(leste, sul).
dir_direita(sul, oeste).
dir_direita(oeste, norte).

dir_esquerda(norte, oeste).
dir_esquerda(oeste, sul).
dir_esquerda(sul, leste).
dir_esquerda(leste, norte).

dir_oposta(norte, sul).
dir_oposta(sul, norte).
dir_oposta(leste, oeste).
dir_oposta(oeste, leste).

% próximo passo considerando uma direção desejada
proximo_passo(Dir, X, Y) :-
    posicao(PX, PY, _),
    ( Dir = norte -> X is PX, Y is PY + 1
    ; Dir = sul   -> X is PX, Y is PY - 1
    ; Dir = leste -> X is PX + 1, Y is PY
    ; Dir = oeste -> X is PX - 1, Y is PY).

alinha_ou_anda(Desejada, andar) :-
    posicao(_, _, Desejada), !.
alinha_ou_anda(Desejada, virar_direita) :-
    posicao(_, _, Atual),
    dir_direita(Atual, Desejada), !.
alinha_ou_anda(Desejada, virar_esquerda) :-
    posicao(_, _, Atual),
    dir_esquerda(Atual, Desejada), !.
alinha_ou_anda(Desejada, virar_direita) :-
    posicao(_, _, Atual),
    dir_oposta(Atual, Desejada), !. % rotaciona quando está oposto

% Log de decisões para depuração
log_decisao(Motivo, Acao) :-
    posicao(PX, PY, Dir),
    format('DECISAO (~w,~w,~w): ~w -> ~w~n', [PX, PY, Dir, Motivo, Acao]).

executa_acao(pegar) :-
    posicao(X, Y, _),
    tile(X, Y, 'O'),
    log_decisao(ouro_na_posicao, pegar), !.

executa_acao(Acao) :-
    ouros_restantes(0),
    posicao(1, 1, _),
    Acao = virar_direita,
    log_decisao(fim_jogo_base, Acao), !. % apenas gira para indicar que terminou

executa_acao(Acao) :-
    ouros_restantes(0),
    caminho_base_seguro(Dir),
    alinha_ou_anda(Dir, Acao),
    log_decisao(retornar_base, Acao), !.

% Fallback antigo para voltar caso BFS falhe
executa_acao(Acao) :-
    ouros_restantes(0),
    melhor_retorno_base(X, Y),
    direcao_para(X, Y, Dir),
    alinha_ou_anda(Dir, Acao),
    log_decisao(retornar_base, Acao), !.

executa_acao(Acao) :-
    adjacente_seguro_nao_visitado(X, Y),
    direcao_para(X, Y, Dir),
    alinha_ou_anda(Dir, Acao),
    log_decisao(avancar_seguro, Acao), !.

% Passo seguro em direção a uma fronteira segura alcançável via BFS
executa_acao(Acao) :-
    caminho_seguro_fronteira(TX, TY, Dir),
    alinha_ou_anda(Dir, Acao),
    log_decisao(rumo_fronteira(TX,TY), Acao), !.

executa_acao(Acao) :-
    melhor_visitado_para_explorar(X, Y),
    direcao_para(X, Y, Dir),
    alinha_ou_anda(Dir, Acao),
    log_decisao(explorar_visitado(X,Y), Acao), !.

% Quando está sem fronteira segura ao redor, volta em direção à base
executa_acao(Acao) :-
    \+ adjacente_seguro_nao_visitado(_, _),
    fronteiras_seguras([]),
    direcao_para(1, 1, Dir),
    alinha_ou_anda(Dir, Acao),
    fronteira_segura(Front),
    log_decisao(sem_fronteira_segura(Front), Acao), !.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Funcoes Auxiliares de navegação e observação
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%Define as 4 adjacencias		 
adjacente(X, Y) :- posicao(PX, Y, _), map_size(MAX_X,_),PX < MAX_X, X is PX + 1.  
adjacente(X, Y) :- posicao(PX, Y, _), PX > 1, X is PX - 1.  
adjacente(X, Y) :- posicao(X, PY, _), map_size(_,MAX_Y),PY < MAX_Y, Y is PY + 1.  
adjacente(X, Y) :- posicao(X, PY, _), PY > 1, Y is PY - 1.  

%cria lista com a adjacencias
adjacentes(L) :- findall(Z,(adjacente(X,Y),tile(X,Y,Z)),L).

%define observacoes locais
observacao_loc(brilho,L) :- member('O',L).
observacao_loc(reflexo,L) :- member('U',L).

%define observacoes adjacentes
observacao_adj(brisa,L) :- member('P',L).
observacao_adj(palmas,L) :- member('T',L).
observacao_adj(passos,L) :- member('D',L).
observacao_adj(passos,L) :- member('d',L).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Tratamento de KB e observações
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

gravar_sensacao_atual :-
    posicao(X, Y, _),
    observacoes(ListaSensores), % Pega o que está sentindo AGORA (brisa, passos...)
    retractall(local_sensacao(X, Y, _)),
    assert(local_sensacao(X, Y, ListaSensores)).

% remove sensores já explicados por perigos certos adjacentes
filtra_sensores([], []).
filtra_sensores([S|T], R) :-
    posicao(PX, PY, _),
    ( sensacao_explicada(S, PX, PY) ->
        limpa_sensor_explicado(PX, PY, S),
        filtra_sensores(T, R)
    ;   filtra_sensores(T, RT), R = [S|RT]
    ).

% remove um sensor das memórias dos vizinhos quando já há uma certeza explicando
limpa_sensor_explicado(SX, SY, Sensor) :-
    vizinho_de(SX, SY, NX, NY),
    \+ certeza(NX, NY),
    \+ visitado(NX, NY),
    memory(NX, NY, Mem),
    member(Sensor, Mem),
    delete_elem(Mem, Sensor, Nova),
    retract(memory(NX, NY, Mem)),
    assert(memory(NX, NY, Nova)),
    fail.
limpa_sensor_explicado(_, _, _).

%consulta e processa observações
atualiza_obs:-
		gravar_sensacao_atual,
		adj_cand_obs(LP), 
		observacoes(LO0),
		filtra_sensores(LO0, LO),
		iter_pos_list(LP,LO), 
		observacao_certeza,
		triangulacao,
		deduz_sensacao_unica,
		observacao_vazia, 
		reportar_status.

%adjacencias candidatas p/ a observacao (aquelas não visitadas)
adj_cand_obs(L) :- findall((X,Y), (adjacente(X, Y), \+visitado(X,Y)), L).

%cria lista de observacoes
observacoes(X) :- adjacentes(L), findall(Y, observacao_adj(Y,L), X).

%itera posicoes da lista para adicionar observacoes
iter_pos_list([], _) :- !.
iter_pos_list([H|T], LO) :- H=(X,Y), 
							((corrige_observacoes_antigas(X, Y, LO),!);
							adiciona_observacoes(X, Y, LO)),
							iter_pos_list(T, LO).							 

% Se uma sensacao registrada em alguma sala tem exatamente um vizinho incerto,
% marcamos essa casa como certeza. Não reutiliza memória anterior para evitar falsos positivos.
deduz_sensacao_unica :-
    local_sensacao(SX, SY, Sensacoes),
    member(Sensor, [brisa,palmas,passos]),
    member(Sensor, Sensacoes),
    \+ sensacao_explicada(Sensor, SX, SY),
    findall((NX, NY), (
        vizinho_de(SX, SY, NX, NY),
        \+ visitado(NX, NY),
        \+ certeza(NX, NY)
    ), Cands),
    length(Cands, 1),
    Cands = [(TX, TY)],
    retractall(memory(TX, TY, _)),
    assert(memory(TX, TY, [Sensor])),
    assert(certeza(TX, TY)),
    write('DEDUTOR: Certeza '), write(Sensor), write(' em '), write(TX), write(','), writeln(TY),
    fail.
deduz_sensacao_unica :- true.

%Corrige observacoes antigas na memoria que ficaram com apenas uma adjacencia
corrige_observacoes_antigas(X, Y, []):- \+certeza(X,Y), memory(X,Y,[]).
corrige_observacoes_antigas(X, Y, LO):- \+certeza(X,Y), memory(X,Y,[]), LO \= [], 
	retract(memory(X,Y,[])), assert(memory(X,Y,LO)).
corrige_observacoes_antigas(X, Y, LO):-
	\+certeza(X,Y), \+ memory(X,Y,[]), memory(X, Y, LM), intersection(LO, LM, L), 
	retract(memory(X, Y, LM)), assert(memory(X, Y, L)).

%Adiciona observacoes na memoria
adiciona_observacoes(X, Y, _) :- certeza(X,Y),!.
adiciona_observacoes(X, Y, LO) :- \+certeza(X,Y), \+ memory(X,Y,_), assert(memory(X, Y, LO)).

%Quando há apenas uma observação e uma unica posição incerta, deduz que a observação está na casa incerta
%e marca como certeza
%observacao_certeza:- findall((X,Y), (adjacente(X, Y), 
%						((\+visitado(X,Y), \+certeza(X,Y));(certeza(X,Y),memory(X,Y,ZZ),ZZ\=[])),
%						memory(X,Y,Z), Z\=[]), L), ((length(L,1),L=[(XX,YY)], assert(certeza(XX,YY)),!);true).
						
observacao_certeza:- observacao_certeza('brisa'),
						observacao_certeza('palmas'),
						observacao_certeza('passos').
						
observacao_certeza(Z):- findall((X,Y), (adjacente(X, Y), 
						((\+visitado(X,Y), \+certeza(X,Y));(certeza(X,Y),memory(X,Y,[Z]))),
						memory(X,Y,[Z])), L), ((length(L,1),L=[(XX,YY)], assert(certeza(XX,YY)),!);true).						

%Quando posição não tem observações
observacao_vazia:- adj_cand_obs(LP), observacao_vazia(LP).
observacao_vazia([]) :- !.
observacao_vazia([H|T]) :- H=(X,Y), ((memory(X,Y,[]), \+certeza(X,Y),assert(certeza(X,Y)),!);true), observacao_vazia(T).

%Quando posicao é visitada, atualiza memoria de posicao com a informação real do mapa 
set_real(X,Y):- ((retract(certeza(X,Y)), assert(certeza(X,Y)),!); assert(certeza(X,Y))), set_real2(X,Y),!.
set_real2(X,Y):- tile(X,Y,'P'), ((retract(memory(X,Y,_)),assert(memory(X,Y,[brisa])),!);assert(memory(X,Y,[brisa]))),!.
set_real2(X,Y):- tile(X,Y,'O'), ((retract(memory(X,Y,_)),assert(memory(X,Y,[brilho])),!);assert(memory(X,Y,[brilho]))),!.
set_real2(X,Y):- tile(X,Y,'T'), ((retract(memory(X,Y,_)),assert(memory(X,Y,[palmas])),!);assert(memory(X,Y,[palmas]))),!.
set_real2(X,Y):- ((tile(X,Y,'D'),!); tile(X,Y,'d')), ((retract(memory(X,Y,_)),assert(memory(X,Y,[passos])),!);assert(memory(X,Y,[passos]))),!.
set_real2(X,Y):- tile(X,Y,'U'), ((retract(memory(X,Y,_)),assert(memory(X,Y,[reflexo])),!);assert(memory(X,Y,[reflexo]))),!.
set_real2(X,Y):- tile(X,Y,''), ((retract(memory(X,Y,_)),assert(memory(X,Y,[])),!);assert(memory(X,Y,[]))),!.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Mostra mapa real
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
show_player(X,Y) :- posicao(X,Y, norte), write('^'),!.
show_player(X,Y) :- posicao(X,Y, oeste), write('<'),!.
show_player(X,Y) :- posicao(X,Y, leste), write('>'),!.
show_player(X,Y) :- posicao(X,Y, sul), write('v'),!.
show_player(X,Y) :- posicao(X,Y, morto), write('+'),!.

show_position(X,Y) :- (show_player(X,Y); write(' ')), tile(X,Y,Z), ((Z='', write(' '));write(Z)),!.

show_map :- map_size(_,MAX_Y), show_map(1,MAX_Y),!.
show_map(X,Y) :- Y >= 1, map_size(MAX_X,_), X =< MAX_X, show_position(X,Y), write(' | '), XX is X + 1, show_map(XX, Y),!.
show_map(X,Y) :- Y >= 1, map_size(X,_),YY is Y - 1, write(Y), nl, show_map(1, YY),!.
show_map(_,0) :- energia(E), pontuacao(P), write('E: '), write(E), write('   P: '), write(P),!.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Mostra mapa conhecido
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

show_mem_info(X,Y) :- memory(X,Y,Z), 
		((visitado(X,Y), write('.'),!); (\+certeza(X,Y), write('?'),!); (certeza(X,Y), write('!'))),
		((member(brisa, Z), write('P'));write(' ')),
		((member(palmas, Z), write('T'));write(' ')),
		((member(brilho, Z), write('O'));write(' ')),
		((member(passos, Z), write('D'));write(' ')),
		((member(reflexo, Z), write('U'));write(' ')),!.

show_mem_info(X,Y) :- \+memory(X,Y,[]), 
			((visitado(X,Y), write('.'),!); (\+certeza(X,Y), write('?'),!); (certeza(X,Y), write('!'))),
			write('     '),!.			

show_mem_position(X,Y) :- posicao(X,Y,_), 
		((visitado(X,Y), write('.'),!); (certeza(X,Y), write('!'),!); write(' ')),
		write(' '), show_player(X,Y),
		((memory(X,Y,Z),
		((member(brilho, Z), write('O'));write(' ')),
		((member(passos, Z), write('D'));write(' ')),
		((member(reflexo, Z), write('U'));write(' ')),!);
		(write('   '),!)).
	
show_mem_position(X,Y) :- show_mem_info(X,Y),!.

show_mem :- map_size(_,MAX_Y), show_mem(1,MAX_Y),!.
show_mem(X,Y) :- Y >= 1, map_size(MAX_X,_), X =< MAX_X, show_mem_position(X,Y), write('|'), XX is X + 1, show_mem(XX, Y),!.
show_mem(X,Y) :- Y >= 1, map_size(X,_),YY is Y - 1, write(Y), nl, show_mem(1, YY),!.
show_mem(_,0) :- energia(E), pontuacao(P), write('E: '), write(E), write('   P: '), write(P),!.
