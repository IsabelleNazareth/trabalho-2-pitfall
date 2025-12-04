
:-dynamic posicao/3.
:-dynamic memory/3.
:-dynamic visitado/2.
:-dynamic certeza/2.
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
	


reset_game :- retractall(memory(_,_,_)), 
			retractall(visitado(_,_)), 
			retractall(certeza(_,_)),
			retractall(energia(_)),
			retractall(pontuacao(_)),
			retractall(posicao(_,_,_)),
			retractall(collected(_,_)),
			retractall(local_sensacao(_,_,_)),
			assert(energia(100)),
			assert(pontuacao(0)),
			assert(posicao(1,1, norte)).


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

% Regra Genérica: Tenta triangular perigos
triangulacao :-
    (tenta_triangular(passos); true),
    (tenta_triangular(palmas); true),
    (tenta_triangular(brisa); true), !.

tenta_triangular(Sensor) :-
    % 1. Pega duas posições ONDE SENTI O PERIGO
    %visitado(X1, Y1), local_sensacao(X1, Y1, Sens1), member(Sensor, Sens1),
    %visitado(X2, Y2), local_sensacao(X2, Y2, Sens2), member(Sensor, Sens2),
    conhecido(X1, Y1), local_sensacao(X1, Y1, Sens1), member(Sensor, Sens1),
    conhecido(X2, Y2), local_sensacao(X2, Y2, Sens2), member(Sensor, Sens2),
	(X1 \= X2 ; Y1 \= Y2),
    
    %Acha a interseção (vizinhos comuns aos dois) que ainda não visitei
    findall((NX, NY), (
        vizinho_de(X1, Y1, NX, NY),
        vizinho_de(X2, Y2, NX, NY),
        %\+ visitado(NX, NY)
		\+ conhecido(NX, NY)

    ), Comuns),
    
    %Se sobrou EXATAMENTE UM candidato
    sort(Comuns, Unicos),
    length(Unicos, 1),
    Unicos = [(TargetX, TargetY)],
    
    %Verifica
    \+ certeza(TargetX, TargetY),
    
    %Confirma o perigo na memoria geral
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
        (\+ visitado(X,Y), certeza(X,Y), memory(X,Y,M), member(passos, M))
    ), Lista),
    sort(Lista, Unicos), length(Unicos, N).

pocos_encontrados(N) :-
    findall((X,Y), (
        (conhecido(X,Y), tile(X,Y,'P'));
        (\+ conhecido(X,Y), certeza(X,Y), memory(X,Y,M), member(brisa, M))
    ), Lista),
    sort(Lista, Unicos), length(Unicos, N).

teleportes_encontrados(N) :-
    findall((X,Y), (
        (conhecido(X,Y), tile(X,Y,'T'));
        (\+ conhecido(X,Y), certeza(X,Y), memory(X,Y,M), member(palmas, M))
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
				retract(posicao(X,Y,Z)), assert(posicao(NX,NY,Z)), atualiza_obs, verifica_player,!.
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

%andar
andar :- posicao(X,Y,P), P = norte, map_size(_,MAX_Y), Y < MAX_Y, YY is Y + 1,
		 limpar_rastro(X,Y), % Limpa o ouro ao sair
         retract(posicao(X,Y,_)), assert(posicao(X, YY, P)), 
		 set_real(X,YY),
		 ((retract(visitado(X,Y)), assert(visitado(X,Y))); assert(visitado(X,Y))),atualiza_pontuacao(-1),!.
		 
andar :- posicao(X,Y,P), P = sul,  Y > 1, YY is Y - 1, 
		 limpar_rastro(X,Y), % Limpa o ouro ao sair
         retract(posicao(X,Y,_)), assert(posicao(X, YY, P)), 
		 set_real(X,YY),
		 ((retract(visitado(X,Y)), assert(visitado(X,Y))); assert(visitado(X,Y))),atualiza_pontuacao(-1),!.

andar :- posicao(X,Y,P), P = leste, map_size(MAX_X,_), X < MAX_X, XX is X + 1, 
		 limpar_rastro(X,Y), % Limpa o ouro ao sair
         retract(posicao(X,Y,_)), assert(posicao(XX, Y, P)), 
		 set_real(XX,Y),
		 ((retract(visitado(X,Y)), assert(visitado(X,Y))); assert(visitado(X,Y))),atualiza_pontuacao(-1),!.

andar :- posicao(X,Y,P), P = oeste,  X > 1, XX is X - 1, 
		 limpar_rastro(X,Y), % Limpa o ouro ao sair
         retract(posicao(X,Y,_)), assert(posicao(XX, Y, P)), 
		 set_real(XX,Y),
		 ((retract(visitado(X,Y)), assert(visitado(X,Y))); assert(visitado(X,Y))),atualiza_pontuacao(-1),!.
		 
%pegar	
pegar :- posicao(X,Y,_), tile(X,Y,'O'), retract(tile(X,Y,'O')), assert(tile(X,Y,'')), atualiza_pontuacao(-5), atualiza_pontuacao(500),set_real(X,Y),!. 
pegar :- posicao(X,Y,_), tile(X,Y,'U'), retract(tile(X,Y,'U')), assert(tile(X,Y,'')), atualiza_pontuacao(-5), atualiza_energia(50),set_real(X,Y),!. 
pegar :- atualiza_pontuacao(-5),!.

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

%consulta e processa observações
atualiza_obs:-
		gravar_sensacao_atual,
		adj_cand_obs(LP), 
		observacoes(LO), 
		iter_pos_list(LP,LO), 
		observacao_certeza,
		triangulacao,
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

%Corrige observacoes antigas na memoria que ficaram com apenas uma adjacencia
corrige_observacoes_antigas(X, Y, []):- \+certeza(X,Y), memory(X,Y,[]).
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
