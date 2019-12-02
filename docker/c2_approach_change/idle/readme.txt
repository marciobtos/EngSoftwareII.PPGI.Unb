********************************************************************
Revisor 2 EAAI:
********************************************************************
Q3. in page 10-11, you observed that some agents stay idle because other agents have enough resource. 
The problem is to find, in a decentralized way, an appropriate task allocation among UAVs so that the quantity and quality of the performed tasks is maximized and the time spent on it is minimized. 
Is there a proof that when some agents are idle, the objective is not optimally reached?

********************************************************************
Experimentos realizados para verificar o que acontece quando:
********************************************************************
Caso um UAV estiver muito pr�ximo das tarefas e os outros muito longe, a ponto de que um �nico agente consiga realizar todas as tarefas mesmo antes dos outros agentes terem tempo de chegar at� ela. 
Neste caso, por exemplo, ser� melhor que apenas um agente execute todas elas.

********************************************************************
Cen�rio:
********************************************************************

Algoritmos: Swarm-GAP, AL, SAL, LAL.
00_swarm-gap_antecipado
01_AL_swarm-gap-loop_antecipado
02_SAL_swarm-gap-loop-ordenado
03_LAL_swarm-gap-loop-limite

Todas as tarefas podem ser executadas por todos (com a mesma qualidade??).
Coloquei para que todos tenham o mesmo sensor, e que todas as tarefas sejam iguais.

Altera��es:
	file "bases/relatorios.nls"
		alterei metodo "run-n-times-all"
		add     m�todo ""
	file "base/dados.nls"
		add metodo "get_3tasks_idle"
		add metodo "get_3uavs_idle"
	