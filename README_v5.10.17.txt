RBT M5 Hybrid v5.10.17

Instalare
1. Copiaza folderul RBT_M5_V5_v5.10.17 complet in MQL5\Experts\Advisors.
2. Pastreaza subfolderele Files si Visual langa fisierul MQ5.
3. Deschide RBT_M5_Hybrid_v5.10.17.mq5 in MetaEditor si apasa F7.
4. Selecteaza acest Expert in Strategy Tester, EURUSD M5, tickuri reale.
5. Pentru continuarea testelor: perioada 2026, InpHybridRunLabel=2026_V5117,
   InpRecoveryMode=1 si InpRecoveryFailureProtection=true.
   Pastreaza restul setarilor folosite in 2024/2025, inclusiv stop=160.

Corectia de initializare
- Mesajul generic din v5.10.16 nu permite identificarea cauzei exacte.
  Parametrii Recovery vizibili in captura sunt valizi; un parametru ascuns
  sau un esec la deschiderea CSV nu pot fi deosebite din acea captura.
- Parametrii invalidi sunt acum identificati explicit, prin nume.
- CSV-urile primesc acelasi identificator de sesiune in toate cele sase loggere.
  O rulare noua foloseste un nume nou, fara reutilizarea CSV-urilor vechi.
- Eticheta este curatata de caractere nepermise si de caractere de control.
- Numele arata modul real: RECOVERY_ONLY, RECOVERY_WITH_TRAIL sau NORMAL_HYBRID.
- Recovery foloseste aceeasi optiune Common Files ca celelalte loggere,
  codare UTF-8 si acces partajat pentru citire.
- Un esec de deschidere/scriere raporteaza fisierul si codul erorii MT5.
  Nu dezactiveaza automat protectiile pentru a forta pornirea.

Grafice restaurate
- Etichete interne si externe: HH, HL, LH, LL, EH, EL.
- BOS si CHOCH pentru structura externa.
- Checkbox Structure lines: traseu intern portocaliu si extern auriu.
  Implicit liniile sunt ascunse; etichetele raman vizibile.
- Algoritmii de swing si functiile de desen provin din v3p5.7.10.
- Overlay-ul se actualizeaza la bara M5 noua, in live si tester vizual.
  In tester fara vizualizare nu efectueaza desenarea/calculul structurii.
- Afisarea XGBoost/Motif din panoul actual ramane disponibila.

Comparabilitate
Logica Recovery, evaluarea failure la 60 minute, pragurile -20/+10/+5,
activarea failure la -40, stopul -160 si esantionarea au ramas identice.
XGBoost, Motif, lotul, regulile de intrare si regulile de inchidere nu au fost
modificate. Filtrul de 12 ore nu este inclus. Cazurile NO_HISTORY observate
in analiza 2025 nu au fost modificate in aceasta versiune.

Verificare efectuata
- Identitate a codului de tranzactionare si a modelelor fata de v5.10.16.
- Dependente locale complete si verificarea codului grafic portat.
- Teste locale C++ cu API MT5 simulat: 256 combinatii de validare, nume CSV,
  sesiuni diferite, erori de deschidere/scriere, HH/HL/LH/LL, toggle linii.
- Aceste teste nu inlocuiesc compilarea MQL5 sau un backtest MT5.
  MetaEditor/MT5 nu sunt disponibile in mediul de pregatire.
  Arhiva contine surse si modele; nu contine un EX5 compilat.

Daca initializarea inca esueaza, trimite linia RECOVERY invalid inputs sau
RECOVERY CSV open failed din Journal, impreuna cu codul error=...
Pastreaza toate CSV-urile care au acelasi sufix RUN pentru fiecare raport HTML.
