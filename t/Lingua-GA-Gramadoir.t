#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More tests => 4+462;
use Lingua::GA::Gramadoir::Languages;
use Lingua::GA::Gramadoir;
use Encode 'decode';

BEGIN { use_ok('Lingua::GA::Gramadoir') };

my $lh = Lingua::GA::Gramadoir::Languages->get_handle('ga');

ok( defined $lh, 'Irish language handle created' );

my $gr = new Lingua::GA::Gramadoir(
			fix_spelling => 1,
			use_ignore_file => 0,
			interface_language => 'ga',
			input_encoding => 'ISO-8859-1');

ok (defined $gr, 'grammar checker created' );

my $test = <<'EOF';
N� raibh l�on m�r daoine bainteach leis an scaifte a bh� ag iarraidh mioscais a choth�.
Ach thosna�os-sa ag l�amh agus bhog m� isteach ionam f�in.
Tabhair go leor leor de na na ruda� do do chara, a Chaoimh�n.
Seo � a chuntas f�in ar ar tharla ina dhiaidh sin (OK).
Aithn�onn ciar�g ciar�g eile (OK).
Go deo deo ar�s n� fheicfeadh s� a cheannaithe snoite (OK).
Tabhair iad seo do do mh�thair (OK).
Sin � � ...  T� s� anseo (OK)!
T� siad le feice�il ann le fada fada an l� (OK).
Bh� go leor leor le r� aici (OK).
Cuirfidh m� m� f�in in aithne d� l�n cin�ocha (OK).
Fanann r�alta chobhsa� ar feadh idir milli�n agus milli�n milli�n bliain (OK).
Bh�odh an-t�ir ar sp�osra� go m�r m�r (OK).
Bh� an dara cup�n tae �lta agam nuair a th�inig an fear m�r m�r.
Agus sin sin de sin (OK)!
Chuaigh s� in olcas ina dhiaidh sin agus bh� an-imn� orthu.
Tharla s� seo ar l� an-m�fheili�nach, an D�ardaoin.
N� maith liom na daoine m�intleacht�la.
Tr� chomhtharl�int, bh� siad sa tuaisceart ag an am.
S�lim n�rbh ea, agus is docha nach bhfuil i gceist ach easpa smaoinimh.
T� s�il le feabhas nuair a thos�idh airgead ag teacht isteach � ola agus g�s i mBearna Timor.
Bh� s� cos�il le cla�omh Damocles ar crochadh sa sp�ir.
Beidh nuacht�in shuaracha i ngreim c� nach mbeadh cinsireacht den droch-chin�al i gceist.
Bh� s� p�irteach sa ch�ad l�iri� poibl� de Riverdance.
Beidh an tionchar le moth� n�os m� i gc�s comhlachta� �ireannacha mar gur mionairgeadra � an punt.
Bh� an dream d�-armtha ag iarraidh a gcuid gunna�.
An bhfuil ayn uachtar roeite agattt?
B�onn an ge�l ag satailt ar an dubh.
Ach go rithe an fh�r�antacht mar uisce agus an t-ionracas mar shruth gan d�sc (OK)!
Ba iad mo shinsear rithe Ch�ige Uladh.
Is iad na tr� chol�n sin le cheile an tAontas Eorpach.
D�antar an glas seo a scri��il ar ch�l an doras.
Ach bh� m� ag lean�int ar aghaidh an t-am ar fad leis (OK).
Bhain s� sult as cl�r toghch�in TG4 a chur i l�thair an mh� seo caite (OK).
Bhrostaigh s� go dt� an t-ospid�al (OK).
Sa dara alt, d�an cur s�os ar a bhfaca siad sa Sp�inn.
D'oirfeadh s�ol �iti�il n�os fearr n� an s�ol a hadhlaic s� anuraidh.
N� hinis do dhuine ar bith � (OK).
T� ceacht stairi�il uath�il do chuairteoir� san t-ionad seo.
Faightear an t-ainm isteach faoin t�r freisin (OK).
C�n t-ainm at� air (OK)?
Aistr�odh � go tSualainnis, Gearm�inis, agus Fraincis.
C�n chaoi a n-aims�onn scoil an tseirbh�s seo (OK)?
T� sonra� ann faoin tsl� ina n-iarrtar taifid faoin Acht (OK).
C�n tsl� bheatha a bh� ag Naoi (OK)?
Bh� imn� ag teacht ar dhearth�ir an tsagairt (OK).
T� s� riachtanach ar mhaithe le feidhmi� an phlean a bheidh ceaptha ag an eagra�ocht ceannasach.
Bh� na ranganna seo ar si�l an bhliain seo caite (OK).
L�imeann an fharraige c�ad m�adar suas sa sp�ir (OK).
Briseadh b�d �amoinn �ig o�che gaoithe m�ire (OK).
Bh�odh na daoir scaoilte saor �na gcuid oibre agus bh�odh saoirse cainte acu (OK).
Bh� m� ag t�g�il balla agus ag baint m�na (OK).
Is as Londain Shasana m� � dh�chas (OK).
Mar chuid den socr� beidh Michelle ag labhairt Ghaeilge ag �c�id� poibl�.
T� d�n cosanta eile ar an taobh thoir den oile�n (OK).
D�an teagmh�il leis an Rann�g ag an seoladh thuasluaite (OK).
T� na lachain slachtmhara ar eitilt.
Mhair cuid mh�r d�r sinsir c�ad caoga bliain � shin (OK).
T� s� le cloiste�il sna me�in gach seachtain (OK).
D�anann siad na breise�in brabhs�la don tionscal r�omhaireachta.
Is ar �isc mara agus ar na hainmhithe mara eile at�imid ag d�ri�.
Chonaic m� l�on agus crainn t�g�la ann (OK).
Bh� picti�ir le feice�il ar sc�ile�in theilif�se ar fud an domhain.
Maidin l� ar na mh�rach thug a fhear gaoil cuairt air.
Cad � mar a t� t�?
A aon, a d�, a tr�.
Ba � a aon aidhm ar an saol daoine a ghn�th� don ch�is (OK).
T� an Rialtas tar �is �it na Gaeilge i saol na t�re a ceisti�.
Ach sin sc�al eile mar a d�arfadh an t� a d�arfadh (OK).
Is ioma� uair a fuair m� locht ar an rialtas (OK).
Bh�odar ag r� ar an aonach gur agamsa a bh� na huain ab fearr.
N� bheidh ach mhallacht i nd�n d� � na cin�ocha agus fuath � na n�isi�in.
N� theasta�onn uaithi ach bheith ina ball den chumann (OK).
An bhfuil aon uachtar reoite ar an cuntar?
Baintear feidhm as chun aic�d� s�l a mhaol� (OK).
M� shu�onn t� ag bhord le flaith, tabhair faoi deara go c�ramach c�ard at� leagtha romhat.
Bl�tha�onn s� amhail bhl�th an mhachaire.
An chuir an bhean bheag m�r�n ceisteanna ort?
An ndeachaigh t� ag iascaireacht inniu (OK)?
An raibh aon bhealach praitici�il eile chun na hInd (OK)?
An bainim sult as b�s an drochdhuine?
An �ireodh n�os fearr leo d� mba mar sin a bheid�s (OK)?
N� f�idir an Gaeltacht a choinne�il mar r�igi�n Gaeilge go n�isi�nta gan athr� bun�sach.
I gc�s An Comhairle Eala�on n� m�r � seo a dh�anamh.
An bean sin, t� s� ina m�inteoir.
Chuala s� a mh�thair ag labhairt chomh caoin seo leis an mbean nua (OK).
Chinn s� an cruinni� a chur ar an m�ar fhada (OK).
Cad � an chomhairle a thug an ochtapas d�?
An Acht um Chomhionannas Fosta�ochta.
Dath b�nbhu� �adrom at� ar an adhmad (OK).
Ch�irigh s� na lampa� le solas a chaitheamh os comhair an coinnleora.
Comhl�n�idh saor�nacht an Aontais an saor�nacht n�isi�nta agus n� ghabhfaidh s� a hionad.
N� raibh guth an s�il�ara le clos a thuilleadh.
T� sin r�ite cheana f�in acu le muintir an t�re seo.
Is � is d�ich� go raibh baint ag an eisimirce leis an laghd� i l�on an gcainteoir� Gaeilge.
Is iad an tr� chol�n le ch�ile an tAontas Eorpach.
Sheol an ceithre mh�le de na meirligh amach san fh�sach (OK).
N� bh�onn an dh�ograis ch�anna n� an dh�thracht ch�anna i gceist.
Ba � an fear an phortaigh a th�inig thart leis na pl�ta� bia.
T� dh� shiombail ag an bharr gach leathanaigh.
An fh�idir le duine ar bith eile breathn� ar mo script?
N� bh�onn aon dh� chl�r as an chrann c�anna mar a ch�ile go d�reach.
N� bheidh aon bunt�iste againn orthu sin.
Rogha aon de na focail a th�inig i d'intinn.
N� hith aon ar�n gabh�la mar aon l�i (OK).
Freagair aon d� cheann ar bith d�obh seo a leanas (OK).
Bh� daoine le f�il i Sasana a chreid gach ar d�radh sa bholscaireacht.
T� treoirl�nte mionsonraithe curtha ar fail ag an gCoimisi�n.
Bh� cead againn fanacht ag obair ar an talamh ar fead tr� mh�.
T� s� an ch�ad su�omh gr�as�n ar bronnadh teastas air (OK).
Bh�omar ag f�achaint ar an Ghaeltacht mar ionad chun feabhas a chur ar ar gcuid Gaeilge.
Cosc a bheith ar cic a thabhairt don sliotar.
Cosc a bheith ar CIC leabhair a dh�ol (OK).
Beidh cairde d� cuid ar Gaeilgeoir� iad (OK).
Ar gcaith t� do chiall agus do ch�adfa� ar fad?
N� amh�in �r dh� chosa, ach nigh �r l�mha!
Gheobhaimid maoin de gach s�rt, agus l�onfaimid �r tithe le creach.
N�l aon n� arbh fi� a shant� seachas �.
Ba maith liom fios a thabhairt anois daoibh.
D�irt daoine go mba ceart an poll a dh�nadh suas ar fad.
Ba eol duit go hioml�n m'anam.
D'fhan beirt buachaill sa champa.
D'fhan beirt bhuachaill cancrach sa champa.
Moth�idh Pobal Osra� an bheirt laoch sin uathu (OK).
N� amh�in bhur dh� chosa, ach nigh bhur l�mha!
D�anaig� beart leis de r�ir bhur briathra.
C� mh�id gealladh ar briseadh ar an Indiach bocht?
Nach raibh a fhios aige c� mh�ad daoine a bh�onn ag �isteacht leis an st�isi�n.
Faigh amach c� mh�ad salainn a bh�onn i sampla d'uisce.
C� �it a nochtfadh s� � f�in ach i mBost�n!
C� ch�s d�inn bheith ag m�inne�il thart anseo?
C� mhinice ba riachtanach d� stad (OK)?
C� n-oibrigh an t-�dar sular imigh s� le ceol?
C� raibh na ruda� go l�ir (OK)?
C� cuireann t� do thr�ad ar f�arach?
C� �s�idfear an mh�in?
C�r f�g t� eisean?
C�r bhf�g t� eisean?
C�r f�gadh eisean (OK)?
Sin � a dh�antar i gcas cuntair oibre cistine.
C� iad na fir seo ag fanacht farat?
C� ea, rachaidh m� ann leat (OK).
C� an ceart at� agamsa a thuilleadh f�s a lorg ar an r�?
D'fhoilsigh s� a c�ad cnuasach fil�ochta i 1995.
Chuir siad fios orm ceithre uaire ar an tsl� sin.
Beidh ar Bhord Feidhmi�ch�in an tUachtar�n agus ceithre ball eile.
T� s� tuigthe aige go bhfuil na ceithre d�ile ann (OK).
C�n amhr�na� is fearr leat?
C�n sl� ar fhoghlaim t� an teanga?
Cha dtug m� cur s�os ach ar dh� bhabhta colla�ochta san �rsc�al ar fad (OK).
Bh� an ch�ad cruinni� den Choimisi�n i Ros Muc i nGaeltacht na Gaillimhe.
T� s� chomh iontach le sneachta dearg.
Chuir m� c�ad punta chuig an banaltra.
N�l t� do do sheoladh chuig dhaoine a labhra�onn teanga dhothuigthe.
Seo deis iontach chun an Ghaeilge a chur chun chinn.
Tiocfaidh deontas faoin alt seo chun bheith in�octha (OK).
D'�ir�d�s ar maidin ar a ceathair a clog.
Bh� s� c�ig bhanl�mh ar fhad, c�ig banl�mh ar leithead.
Beirim mo mhionn dar an beart a rinne Dia le mo shinsir.
Sa dara bliain d�ag d�r braighdeanas, th�inig fear ar a theitheadh.
D'oibrigh m� liom go dt� D� Aoine.
M�le naoi gc�ad a hocht nd�ag is fiche.
Feicim go bhfuil aon duine d�ag curtha san uaigh seo.
D'fh�s s� ag deireadh na nao� haoise d�ag agus f�s an n�isi�nachais (OK).
Tabharfaidh an tUachtar�n a �r�id ag leath i ndiaidh a d� d�ag D� Sathairn.
Bhuail an clog a tr� dh�ag.
T� tr� d�ag litir san fhocal seo.
Bh� deich tobar f�oruisce agus seacht� crann pailme ann.
T�gfaidh m� do coinnleoir �na ionad, mura nd�ana t� aithr�.
Is c�is imn� don pobal a laghad maoinithe a dh�antar ar Na�scoileanna.
Daoine eile at� ina mbaill den dhream seo.
Creidim go raibh siad de an thuairim ch�anna.
T� dh� teanga oifigi�la le st�das bunreacht�il � labhairt sa t�r seo.
Dh� fiacail l�rnacha i ngach aon chomhla.
Rug s� greim ar mo dh� gualainn agus an fhearg a bh� ina s�ile.
Bh� Eibhl�n ar a dh� gl�in (OK).
Is l�ir nach bhfuil an dh� theanga ar chomhch�im lena ch�ile.
Tion�ladh an ch�ad dh� chom�rtas i nGaoth Dobhair.
C� bhfuil feoil le f�il agamsa le tabhairt do an mhuintir?
Is amhlaidh a bheidh freisin do na tagairt� do airteagail.
T� s� de ch�ram seirbh�s a chur ar f�il do a chustaim�ir� i nGaeilge.
Seinnig� moladh ar an gcruit do �r m�thair.
Is � seo mo Mhac muirneach do ar thug m� gnaoi.
T� an domhan go l�ir faoi suaimhneas.
Caithfidh pobal na Gaeltachta iad f�in cinneadh a dh�anamh faoi an Ghaeilge.
Cuireann s� a neart mar chrios faoi a coim.
Cuireann s� cin�ocha faoi �r smacht agus cuireann s� n�isi�in faoin�r gcosa.
T� dualgas ar an gComhairle sin tabhairt faoin c�ram seo.
Tugadh mioneolas faoin dtionscnamh seo in Eagr�n a haon.
Bh� l�ch�ir ar an Tiarna faoina dhearna s�!
N� bheidh gear�n ag duine ar bith faoin gciste fial at� faoin�r c�ram.
Beidh par�id L� Fh�ile Ph�draig i mBost�n.
T� F�ile Bhealtaine an Oireachtais ar si�l an tseachtain seo (OK).
F�gtar na m�lte eile gan gh�aga n� radharc na s�l.
T� ar chumas an duine saol ioml�n a chaitheamh gan theanga eile � br� air.
T� gruaim mh�r orm gan Chaitl�n.
Deir daoine eile, �fach, gur dailt�n gan maith �.
Fuarthas an fear marbh ar an tr�, a chorp gan m�chail gan ghort�.
D�irt s� liom gan p�sadh (OK).
Na duilleoga ar an ngas beag, cruth lansach orthu agus iad gan cos f�thu (OK).
D'fh�g sin gan meas d� laghad ag duine ar bith air (OK).
T� m� gan cos go br�ch (OK).
N�l s� ceadaithe aistri� � rang go ch�ile gan cead a fh�il uaim (OK).
Is st�it ilteangacha iad cuid mh�r de na st�it sin at� aonteangach go oifigi�il.
N� bheidh bonn compar�ide ann go beidh tortha� Dhaon�ireamh 2007 ar f�il.
Rug s� ar ais m� go dhoras an Teampaill.
Tiocfaidh coimhlint� chun tosaigh sa Chumann � am go ch�ile (OK).
Is turas iontach � an turas � bheith i do thosaitheoir go bheith i do mh�inteoir (OK).
T� a chuid leabhar tiontaithe go dh� theanga fichead (OK).
Chuaigh m� suas go an doras c�il a chaisle�in.
Th�inig P�l � Coile�in go mo theach ar maidin.
Bh� an teachtaireacht dulta go m'inchinn.
Tar, t�anam go dt� bhean na bhf�seanna.
Agus rachaidh m� siar go dt� th� tr�thn�na, m�s maith leat (OK).
Ba mhaith liom gur bhf�gann daoine �ga an scoil agus iad ullmhaithe.
Bhraith m� gur fuair m� boladh trom tais uathu.
An ea nach c�s leat gur bhf�g mo dheirfi�r an freastal f�msa i m'aonar?
B'fh�idir gurbh fearr � seo duit n� leamhnacht na b� ba mhilse i gcontae Chill Mhant�in.
T� ainm i n-easnamh a mbeadh coinne agat leis.
T� ainm i easnamh a mbeadh coinne agat leis.
An bhfuil aon uachtar reoite agat i cuisneoir?
An bhfuil aon uachtar reoite agat i chuisneoir?
T�imid ag lorg 200 Club Gailf i gach cearn d'�irinn.
An bhfuil aon uachtar reoite agaibh i bhur m�la?
An bhfuil aon uachtar reoite agat i dh� chuisneoir?
Bh� sl�m de ph�ip�ar tais ag cruinni� i mhullach a ch�ile.
Fuair Derek Bell b�s tobann i Phoenix (OK).
T� n�os m� n� 8500 m�inteoir ann i thart faoi 540 scoil (OK).
An bhfuil aon uachtar reoite agat i an chuisneoir?
An bhfuil aon uachtar reoite agat i na cuisneoir�?
An bhfuil aon uachtar reoite i a cuisneoir?
Roghnaigh na teangacha i a nochtar na leathanaigh seo.
Rinne gach cine � sin sna cathracha i ar lonna�odar.
An bhfuil aon uachtar reoite i �r m�la?
Thug s� seo deis dom breathn� in mo thimpeall.
Ph�s s� P�draig, fear �n mBlascaod M�r, in 1982.
Ph�s s� P�draig, fear �n mBlascaod M�r, in 1892 (OK).
Theastaigh uaibh beirt bheith in bhur scr�bhneoir� (OK).
Beidh an sp�rt seo � imirt in dh� ionad (OK).
Cad � an rud is m� faoi na Gaeil ina chuireann s� suim?
T� beirfean in�r craiceann faoi mar a bheimis i sorn.
Is tuar d�chais � an m�id dul chun cinn at� d�anta le bhlianta beaga.
Leanaig� oraibh le bhur nd�lseacht d�inn (OK).
Baineann an sc�im le thart ar 28,000 miond�olt�ir ar fud na t�re (OK).
N�or cuireadh aon tine s�os, ar nd�igh, le chomh bre� is a bh� an aimsir (OK).
T� s� ag teacht le th� a fheice�il (OK).
D'fh�adfadh t�bhacht a bheith ag baint le an gc�ad toisc d�obh sin.
Molann an Coimisi�n go maoineofa� sc�im chun tac� le na pobail.
Labhra�odh gach duine an fh�rinne le a chomharsa.
Le halt 16 i nd�il le hiarratas ar ord� le a meastar gur tugadh toili�.
Beir i do l�imh ar an tslat le ar bhuail t� an abhainn, agus seo leat.
Ba mhaith liom bu�ochas a ghlacadh le �r seirbh�s riarach�in.
T�gann siad cuid de le iad f�in a th�amh.
T� do scrios chomh leathan leis an farraige.
Cuir alt eile lenar bhfuil scr�ofa agat i gCeist a tr�.
Is linne � ar nd�igh agus len�r clann.
M� tugann r� breith ar na boicht le cothromas, bun�far a r�chathaoir go br�ch.
M� deirim libh �, n� chreidfidh sibh (OK).
M� t� suim agat sa turas seo, seol d'ainm chugamsa (OK).
M� fuair n�or fhreagair s� an facs (OK).
Roghna�tear an bhliain 1961 mar pointe tosaigh don anail�s.
Aithn�tear � mar an �dar�s.
M�s mhian leat tuilleadh eolais a fh�il, scr�obh chugainn.
T� caitheamh na hola ag dul i m�ad i gc�na�.
Tosa�odh ar mhodh adhlactha eile ina mbaint� �s�id as clocha measartha m�ra.
Comhl�on mo aitheanta agus mairfidh t� beo.
Ceapadh mise i mo bolscaire.
T� m� ag scl�bha�ocht ag iarraidh mo dh� gas�r a chur tr� scoil. 
Agus anois bh� m�rsheisear in�onacha ag an sagart.
Mura dtuig siad �, nach d�ibh f�in is m� n�ire?
Mura bhfuair, sin an chraobh aige (OK).
Mura tagann aon duine i gcabhair orainn, rachaimid anonn chugaibh.
Fi� mura �ir�onn liom, beidh m� �balta cabhr� ar bhonn deonach.
Murach bheith mar sin, bheadh s� dodh�anta d� oibri� na huaireanta fada (OK).
Murar chrutha�tear l� agus o�che... teilgim uaim sliocht Iac�ib.
Murar gcruthaigh mise l� agus o�che... teilgim uaim sliocht Iac�ib.
An bhfuil aon uachtar reoite ag fear na b�d?
Is m�r ag n�isi�n na �ireann a choibhneas speisialta le daoine de bhunadh na h�ireann at� ina gc�na� ar an gcoigr�och.
Chuir an Coimisi�n f�in comhfhreagras chuig na eagra�ochta� seo ag lorg eolais faoina ngn�omha�ochta�.
T� an tr�ith sin coitianta i measc na n�ireannaigh sa t�r seo.
Athdh�antar na sn�ithe i ngach ceann de na curaclaim seo.
N� iompa�g� chun na n-�ol, agus n� dealbha�g� d�ithe de mhiotal.
T� t� n�os faide sa t�r n� is dleathach duit a bheith (OK).
Ach n� sin an cult�r a bh� n� at� go f�ill (OK).
Agus creid n� n� chreid, nach bhfuil an l�mhscr�bhinn agam f�in.
N�or th�isce greim bia caite aige n� thug s� an tuath air f�in.
Is fearr de bh�ile luibheanna agus gr� leo n� mhart m�ith agus gr�in leis.
Is fearr an b�s n� bheith beo ar dh�irc (OK).
Nach raibh d�thain eolais aige (OK)?
Nach bainfidh m� uaidh an m�id a ghoid s� uaim?
Nach ghasta a fuair t� �!
Rinneadh an roinnt don naoi treibh go leith ar chrainn.
Th�inig na br�ga chomh fada siar le haimsir Naomh Ph�draig f�in.
N�r bre� liom cla�omh a bheith agam i mo ghlac!
N�r bhfreagair s� th�, focal ar fhocal.
Feicimid gur de dheasca a n-easumhla�ochta n�rbh f�idir leo dul isteach ann.
N� fuaireamar puinn eile tuairisce air i ndiaidh sin.
N� chuireadar aon �thas ar Mhac Dara.
N� d�irt s� cad a bh� d�anta acu (OK).
N� f�adfaidh a gcuid airgid n� �ir iad a sh�bh�il.
N� bhfaighidh t� aon d�irce uaim (OK).
N� deir s� � seo le haon ghr�in (OK).
N� iad sin do ph�opa� ar an t�bla!
N� dheireadh aon duine acu aon rud liom.
N� fh�idir d�ibh duine a shaoradh �n mb�s.
Bh� an m�id sin airgid n�ba luachmhar d�inn n� maoin an domhain.
An raibh duine ar bith acu n� ba bhocht n� eisean?
Eisean beag�n n�b �ga n� mise.
Eisean beag�n n�ba �ige n� mise.
Bh� na p�ist� ag �ir� n�ba tr�ine.
"T�," ar sise, "ach n�or fhacthas � sin."
N�or g� do dheora� riamh codladh sa tsr�id; Bh� mo dhoras riamh ar leathadh.
"T�," ar sise, "ach n�or fuair muid aon ocras f�s.
N�or mbain s� leis an dream a bh� i gcogar ceilge.
N�orbh fol�ir d� �isteacht a thabhairt dom.
T� bonn i bhfad n�os dhoimhne n� sin le F�ilte an Oireachtais.
Eoghan � Anluain a thabharfaidh l�acht deiridh na comhdh�la.
Ach anois � cuimhn�m air, bh� ard�n coincr�ite sa ph�irc.
Bhuel, fan ar strae mar sin � t� t� chomh m�mh�inte sin (OK).
N� maith liom � ar chor ar bith � fuair s� an litir sin (OK).
Tabhair an t-ord� seo leanas � b�al.
B�odh bhur ngr� saor � an chur i gc�ill.
Bh� ocht t�bla ar fad ar a mara�d�s na h�obairt�.
S�ra�onn s� na seacht n� na hocht bliana.
Beidh an ch�ad chruinni� oifigi�il ag an gcoiste o�che D� Luain.
B�onn ranganna ar si�l o�che Dh�ardaoin.
B�odh bhur ngr� saor �n cur i gc�ill.
N� glacaim sos �n thochailt.
Amharcann s� � a ionad c�naithe ar gach aon neach d� maireann ar talamh.
Seo iad a gc�imeanna de r�ir na n-�iteanna � ar thosa�odar.
Agus rinne s� �r bhfuascailt � �r naimhde.
Seo teaghlach ag a bhfuil go leor fadhbanna agus �nar dteasta�onn taca�ocht at� d�rithe.
Bh�odh s�il in airde againn �n�r t�ir faire.
T� do gh�aga spr�ite ar bhraill�n ghl�igeal os fharraige faoile�n.
Ar ais leis ansin os chomhair an teilif�se�in.
Uaidh f�in, b'fh�idir, p� � f�in.
Agus th�inig sc�in air roimh an pobal seo ar a l�onmhaire.
Is gaiste � eagla roimh daoine.
An bhfuil aon uachtar reoite agat sa oighear?
Gorta�odh ceathrar sa n-eachtra.
Abairt a chuireann in i�l dear�ile na h�ireann sa 18� agus sa 19� haois.
An bhfuil aon uachtar reoite agat sa cuisneoir?
N� m�r dom umhl� agus cic maith sa th�in a thabhairt duit. 
An bhfuil aon uachtar reoite agat sa seamair?
An bhfuil aon uachtar reoite agat sa scoil (OK)?
An bhfuil aon uachtar reoite agat sa samhradh (OK)?
T� s� br�thair de chuid Ord San Phroinsias.
San f�sach cuirfidh m� crainn ch�adrais.
An bhfuil aon uachtar reoite agat san foraois?
Tugaimid faoi abhainn na Sionainne san bh�d locha � Ros Com�in.
T�gadh an foirgneamh f�in san 18� haois (OK).
N� f�idir iad a sheinm le sn�thaid ach c�ig n� s� uaire.
D�irt s� uair amh�in nach raibh �it eile ar mhaith leis c�na� ann (OK).
C�ard at� ann n� s� cathaoirleach coiste.
Cuireadh bosca� tice�la isteach seachas bhosca� le freagra� a scr�obh isteach.
D� nd�anfadh s� amhlaidh r�iteodh s� an fhadhb seachas bheith � gh�ar� (OK).
T� seacht lampa air agus seacht p�opa ar gach ceann d�obh.
Is iad na tr� cheist sin (OK).
Lena chois sin, d� bharr seo, d� bhr� sin, ina aghaidh seo (OK).
C�n t-ionadh sin (OK)?
Is siad na ruda� crua a mhairfidh.
T� ar a laghad ceithre n� sa litir a chuir scaoll sna oifigigh.
Sol�thra�onn an Roinn seisi�in sna Gaeilge labhartha do na mic l�inn.
Sula sroicheadar an bun ar�s, bh� an o�che ann agus chuadar ar strae.
Sula ndearna s� amhlaidh, m�s ea, l�irigh s� a chreidi�int san fhoireann (OK).
Iompr�idh siad th� lena l�mha sula bhuailfe� do chos in aghaidh cloiche.
Ach sular sroich s�, d�irt s�: "D�naig� an doras air!"
Chuir iad ina su� mar a raibh on�ir acu thar an cuid eile a fuair cuireadh.
Bh� an chathair ag cur thar maol le fil� de gach cine�l.
Timpeall tr� uaire a chloig ina dhiaidh sin th�inig an bhean isteach.
Scr�obhaim chugaibh mar gur maitheadh daoibh bhur bpeaca� tr� a ainm.
Cuirtear i l�thair na strucht�ir tr� a re�cht�lfar gn�omhartha ag an leibh�al n�isi�nta.
N� fhillfidh siad ar an ngeata tr� ar ghabh siad isteach.
Beirimid an bua go caithr�imeach tr� an t� �d a thug gr� d�inn.
Coinn�odh len�r s�la sa chaoi n�rbh fh�idir si�l tr� �r sr�ideanna.
Gabhfaidh siad tr� muir na h�igipte.
Feidhmeoidh an ciste coimisi�naithe tr�d na foilsitheoir� go pr�omha.
Ba � an gleann c�ng tr�na ghabh an abhainn.
Is mar a ch�ile an pr�iseas tr�nar nd�antar � seo.
Mar tr�n�r peaca�, t� do phobal ina �bhar g�ire ag c�ch m�guaird orainn.
N�r thug s� p�g do gach uile duine?
D'ith na daoine uile bia (OK).
Idir dh� sholas, um tr�thn�na, faoi choim na ho�che agus sa dorchadas.
Strait�is Chomhphobail um bainist�ocht dramha�ola (OK).
Bh�odh an dinn�ar acu um mhe�n lae.
An l� dar gcionn nochtadh gealltanas an Taoisigh sa nuacht�n.
Conas a bheadh �irinn agus Meirice� difri�il?
Ba chois tine � (OK).
Bh� cuid mh�r teannais agus ioma�ochta ann (OK).
Galar cr�ibe is b�il (OK).
Caitheann s� go leor ama ann (OK).
An raibh m�r�n daoine ag an tsiopa?
N� raibh d�il bheo le feice�il ar na bhfuinneog.
Bh�, d�la an sc�il, ocht mbean d�ag aige (OK).
C� bhfuil an tseomra?
Is iad na nGarda�.
�ir� Amach na C�sca (OK).
Leas phobal na h�ireann agus na hEorpa (OK).
F�ilte an deamhain is an diabhail romhat (OK).
Go deo na ndeor, go deo na d�leann (OK).
Clann na bPoblachta a thug siad orthu f�in.
Crutha�odh an chloch sin go domhain faoin dtalamh.
T� ainm in n-easnamh a mbeadh coinne agat leis.
T� muid compordach inar gcuid "f�rinn�" f�in.
T� siad ag �ileamh go n-�ocfa� iad as a gcuid costais agus iad mbun traen�la.
Crutha�odh an chloch sin go domhain faoin gcrann (OK).
Nach holc an mhaise duit a bheith ag magadh.
D�n do bh�al, a mhi�il na haon chloiche (OK)!
Scaoileadh seachtar duine chun b�is i mBaile �tha Cliath le hocht m� anuas (OK).
N� dh�nfaidh an t-ollmhargadh go dt� a haon a chlog ar maidin (OK).
Is mar gheall ar sin at� l�n�ocht phicti�rtha chomh h�s�ideach sin (OK).
T� s� ag feidhmi� go h�ifeachtach (OK).
N� hionann cuingir na ngabhar agus cuingir na l�n�ine (OK).
Ba hiad na hamhr�in i dtosach ba ch�is leis.
N� h� l� na gaoithe l� na scolb (OK).
Ba iad na tr� h�it iad Bost�n, Baile �tha Cliath agus Nua Eabhrac.
Ph�s s� bean eile ina h�it (OK).
C� ham a th�inig s� a staid�ar anseo � th�s (OK)?
Bh� a dhearth�ir ag si�l na gceithre hairde agus bh� seisean ina shu� (OK).
Chaith s� an dara ho�che i Sligeach (OK).
T� s� i gc�ip a rinneadh i l�r na c�igi� haoise d�ag (OK).
Chuir s� a dh� huillinn ar an bhord (OK).
Chuir m� mo dh� huillinn ar an bhord.
Cuireadh cuid mhaith acu go h�irinn (OK).
T� t�s curtha le cl�r chun rampa� luchtaithe a chur sna hotharcharranna (OK).
Cuimhn�g� ar na h�achta� a rinne s� (OK).
Creidim go mbeidh iontas ar mhuintir na h�ireann nuair a fheiceann siad an feidhmchl�r seo (OK).
Th�inig m�inteoir �r i gceithre huaire fichead (OK).
Caithfidh siad turas c�ig huaire a chloig a dh�anamh.
In �irinn chaitheann breis is 30 faoin gc�ad de mhn� toit�n�.
Chuirfear in i�l do dhaoine gurb � sin an aidhm at� againn.
D�an cur s�os ar dh� thoradh a bh�onn ag caitheamh tobac ar an tsl�inte (OK).
M� bhr�itear idir chn�nna agus bhlaoscanna faightear ola inchaite (OK).
N� chotha�onn na briathra na br�ithre (OK).
Cha bh�onn striapachas agus seaf�id Mheirice� ann feasta (OK).
T� cleachtadh ag daoine � bh�onn siad an-�g ar uaigneas imeachta (OK).
Ar an l�ithre�n seo gheofar focl�ir� agus liosta� t�arma�ochta (OK).
An o�che sin, sular chuaigh s� a chodladh, chuir s� litir fhada dom.
T� mioneolas faoinar rinne s� ansin.
N�or rinneadh a leith�id le fada agus n� raibh aon slat tomhais acu.
Teasta�onn uaidh an sc�al a insint sula ngeobhaidh s� b�s.
T� fol�ntas sa chomhlacht ina t� m� ag obair faoi l�thair.
N� gheobhaidh an meallt�ir nathrach aon t�ille.
M� dhearna s� praiseach de, thosaigh s� ar�s go bhfuair s� ceart �.
Chan fhacthas dom go raibh an saibhreas c�anna i mB�arla (OK).
Chuaigh s� chun na huaimhe agus fh�ach s� isteach.
F�gadh faoi smacht a l�mh iad (OK).
An �osf� ubh eile (OK)?
N�orbh fhada, �mh, gur d'fhoghlaim s� an t�arma ceart uathu.
N�lim ag r� gur d'aon ghuth a ainmn�odh Sheehy (OK).
Ritheann an Sl�ine tr�d an ph�irc.
Nochtadh na f�rinne sa d�igh a n-admh�dh an t� is br�aga� � (OK).
T� a chumas sa Ghaeilge n�os airde n� cumas na bhfear �ga.
Beirt bhan Mheirice�nacha a bh� ann (OK).
T� s�-- t� s�- mo ---shin-seanathair (OK).
Is fol�ir d�ibh a ndualgais a chomhl�onadh.
Bhain na toibreacha le re eile agus le dream daoine at� imithe.
Labhair m� ar shon na daoine.
T� s� t�bhachtach bheith ag obair an son na cearta.
EOF

my $results = <<'RESEOF';
<E offset="43" fromy="1" fromx="43" toy="1" tox="49" sentence="Ní raibh líon mór daoine bainteach leis an scaifte a bhí ag iarraidh mioscais a chothú." errortext="scaifte" msg="Foirm neamhchaighdeánach de «scata»">
<E offset="4" fromy="2" fromx="4" toy="2" tox="15" sentence="Ach thosnaíos-sa ag léamh agus bhog mé isteach ionam féin." errortext="thosnaíos-sa" msg="Foirm neamhchaighdeánach de «thosnaigh (thosaigh)»">
<E offset="24" fromy="3" fromx="24" toy="3" tox="28" sentence="Tabhair go leor leor de na na rudaí do do chara, a Chaoimhín." errortext="na na" msg="Focal céanna faoi dhó">
<E offset="51" fromy="4" fromx="51" toy="4" tox="52" sentence="Seo é a chuntas féin ar ar tharla ina dhiaidh sin (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="30" fromy="5" fromx="30" toy="5" tox="31" sentence="Aithníonn ciaróg ciaróg eile (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="55" fromy="6" fromx="55" toy="6" tox="56" sentence="Go deo deo arís ní fheicfeadh sí a cheannaithe snoite (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="32" fromy="7" fromx="32" toy="7" tox="33" sentence="Tabhair iad seo do do mháthair (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="25" fromy="8" fromx="26" toy="8" tox="27" sentence="Sin é é ... Tá sé anseo (OK)!" errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="44" fromy="9" fromx="44" toy="9" tox="45" sentence="Tá siad le feiceáil ann le fada fada an lá (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="29" fromy="10" fromx="29" toy="10" tox="30" sentence="Bhí go leor leor le rá aici (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="47" fromy="11" fromx="47" toy="11" tox="48" sentence="Cuirfidh mé mé féin in aithne dá lán ciníocha (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="74" fromy="12" fromx="74" toy="12" tox="75" sentence="Fanann réalta chobhsaí ar feadh idir milliún agus milliún milliún bliain (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="39" fromy="13" fromx="39" toy="13" tox="40" sentence="Bhíodh an-tóir ar spíosraí go mór mór (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="56" fromy="14" fromx="56" toy="14" tox="62" sentence="Bhí an dara cupán tae ólta agam nuair a tháinig an fear mór mór." errortext="mór mór" msg="Focal céanna faoi dhó">
<E offset="21" fromy="15" fromx="21" toy="15" tox="22" sentence="Agus sin sin de sin (OK)!" errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="45" fromy="16" fromx="45" toy="16" tox="51" sentence="Chuaigh sí in olcas ina dhiaidh sin agus bhí an-imní orthu." errortext="an-imní" msg="Focal anaithnid ach bunaithe ar «imní» is dócha">
<E offset="20" fromy="17" fromx="20" toy="17" tox="35" sentence="Tharla sé seo ar lá an-mífheiliúnach, an Déardaoin." errortext="an-mífheiliúnach" msg="Bunaithe go mícheart ar an bhfréamh «mífheiliúnach»">
<E offset="24" fromy="18" fromx="24" toy="18" tox="37" sentence="Ní maith liom na daoine míintleachtúla." errortext="míintleachtúla" msg="Bunaithe go mícheart ar an bhfréamh «intleachtúla (intleachtacha, intleachtaí)»">
<E offset="4" fromy="19" fromx="4" toy="19" tox="17" sentence="Trí chomhtharlúint, bhí siad sa tuaisceart ag an am." errortext="chomhtharlúint" msg="Bunaithe ar fhoirm neamhchaighdeánach de «tharlú»">
<E offset="24" fromy="20" fromx="24" toy="20" tox="28" sentence="Sílim nárbh ea, agus is docha nach bhfuil i gceist ach easpa smaoinimh." errortext="docha" msg="An raibh «dócha» ar intinn agat?">
<E offset="87" fromy="21" fromx="87" toy="21" tox="91" sentence="Tá súil le feabhas nuair a thosóidh airgead ag teacht isteach ó ola agus gás i mBearna Timor." errortext="Timor" msg="An raibh «Tíomór» ar intinn agat?">
<E offset="25" fromy="22" fromx="25" toy="22" tox="32" sentence="Bhí sí cosúil le claíomh Damocles ar crochadh sa spéir." errortext="Damocles" msg="An raibh «Dámaicléas» ar intinn agat?">
<E offset="66" fromy="23" fromx="66" toy="23" tox="78" sentence="Beidh nuachtáin shuaracha i ngreim cé nach mbeadh cinsireacht den droch-chinéal i gceist." errortext="droch-chinéal" msg="Bunaithe ar fhocal mílitrithe go coitianta «cinéal (cineál)»?">
<E offset="43" fromy="24" fromx="43" toy="24" tox="52" sentence="Bhí sé páirteach sa chéad léiriú poiblí de Riverdance." errortext="Riverdance" msg="Is féidir gur focal iasachta é seo (tá na litreacha «Riv» neamhdhóchúil)">
<E offset="74" fromy="25" fromx="74" toy="25" tox="86" sentence="Beidh an tionchar le mothú níos mó i gcás comhlachtaí Éireannacha mar gur mionairgeadra é an punt." errortext="mionairgeadra" msg="Focal anaithnid ach is féidir gur comhfhocal «mion+airgeadra» é?">
<E offset="13" fromy="26" fromx="13" toy="26" tox="21" sentence="Bhí an dream dí-armtha ag iarraidh a gcuid gunnaí." errortext="dí-armtha" msg="Focal anaithnid ach is féidir gur comhfhocal neamhchaighdeánach «dí+armtha» é?">
<E offset="10" fromy="27" fromx="10" toy="27" tox="12" sentence="An bhfuil ayn uachtar roeite agattt?" errortext="ayn" msg="Focal anaithnid: «aon, ann, an»?">
<E offset="22" fromy="27" fromx="22" toy="27" tox="27" sentence="An bhfuil ayn uachtar roeite agattt?" errortext="roeite" msg="Focal anaithnid: «reoite»?">
<E offset="29" fromy="27" fromx="29" toy="27" tox="34" sentence="An bhfuil ayn uachtar roeite agattt?" errortext="agattt" msg="Is féidir gur focal iasachta é seo (tá na litreacha «ttt» neamhdhóchúil)">
<E offset="9" fromy="28" fromx="9" toy="28" tox="12" sentence="Bíonn an geál ag satailt ar an dubh." errortext="geál" msg="Focal ceart ach an-neamhchoitianta">
<E offset="79" fromy="29" fromx="79" toy="29" tox="80" sentence="Ach go rithe an fhíréantacht mar uisce agus an t-ionracas mar shruth gan dísc (OK)!" errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="19" fromy="30" fromx="19" toy="30" tox="23" sentence="Ba iad mo shinsear rithe Chúige Uladh." errortext="rithe" msg="Ní dócha go raibh intinn agat an modh foshuiteach a úsáid anseo">
<E offset="28" fromy="31" fromx="28" toy="31" tox="33" sentence="Is iad na trí cholún sin le cheile an tAontas Eorpach." errortext="cheile" msg="Ní dócha go raibh intinn agat an modh foshuiteach a úsáid anseo">
<E offset="31" fromy="32" fromx="31" toy="32" tox="46" sentence="Déantar an glas seo a scriúáil ar chúl an doras." errortext="ar chúl an doras" msg="Tá gá leis an leagan ginideach anseo">
<E offset="55" fromy="33" fromx="55" toy="33" tox="56" sentence="Ach bhí mé ag leanúint ar aghaidh an t-am ar fad leis (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="71" fromy="34" fromx="71" toy="34" tox="72" sentence="Bhain sé sult as clár toghcháin TG4 a chur i láthair an mhí seo caite (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="36" fromy="35" fromx="36" toy="35" tox="37" sentence="Bhrostaigh sé go dtí an t-ospidéal (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="3" fromy="36" fromx="3" toy="36" tox="10" sentence="Sa dara alt, déan cur síos ar a bhfaca siad sa Spáinn." errortext="dara alt" msg="Réamhlitir «h» ar iarraidh">
<E offset="48" fromy="37" fromx="48" toy="37" tox="55" sentence="D'oirfeadh síol áitiúil níos fearr ná an síol a hadhlaic sé anuraidh." errortext="hadhlaic" msg="Réamhlitir «h» gan ghá">
<E offset="30" fromy="38" fromx="30" toy="38" tox="31" sentence="Ná hinis do dhuine ar bith é (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="48" fromy="39" fromx="48" toy="39" tox="54" sentence="Tá ceacht stairiúil uathúil do chuairteoirí san t-ionad seo." errortext="t-ionad" msg="Réamhlitir «t» gan ghá">
<E offset="47" fromy="40" fromx="47" toy="40" tox="48" sentence="Faightear an t-ainm isteach faoin tír freisin (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="20" fromy="41" fromx="20" toy="41" tox="21" sentence="Cén t-ainm atá air (OK)?" errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="15" fromy="42" fromx="15" toy="42" tox="25" sentence="Aistríodh é go tSualainnis, Gearmáinis, agus Fraincis." errortext="tSualainnis" msg="Réamhlitir «t» gan ghá">
<E offset="47" fromy="43" fromx="47" toy="43" tox="48" sentence="Cén chaoi a n-aimsíonn scoil an tseirbhís seo (OK)?" errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="58" fromy="44" fromx="58" toy="44" tox="59" sentence="Tá sonraí ann faoin tslí ina n-iarrtar taifid faoin Acht (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="32" fromy="45" fromx="32" toy="45" tox="33" sentence="Cén tslí bheatha a bhí ag Naoi (OK)?" errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="46" fromy="46" fromx="46" toy="46" tox="47" sentence="Bhí imní ag teacht ar dheartháir an tsagairt (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="74" fromy="47" fromx="74" toy="47" tox="94" sentence="Tá sé riachtanach ar mhaithe le feidhmiú an phlean a bheidh ceaptha ag an eagraíocht ceannasach." errortext="eagraíocht ceannasach" msg="Séimhiú ar iarraidh">
<E offset="50" fromy="48" fromx="50" toy="48" tox="51" sentence="Bhí na ranganna seo ar siúl an bhliain seo caite (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="49" fromy="49" fromx="49" toy="49" tox="50" sentence="Léimeann an fharraige céad méadar suas sa spéir (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="46" fromy="50" fromx="46" toy="50" tox="47" sentence="Briseadh bád Éamoinn Óig oíche gaoithe móire (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="78" fromy="51" fromx="78" toy="51" tox="79" sentence="Bhíodh na daoir scaoilte saor óna gcuid oibre agus bhíodh saoirse cainte acu (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="43" fromy="52" fromx="43" toy="52" tox="44" sentence="Bhí mé ag tógáil balla agus ag baint móna (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="36" fromy="53" fromx="36" toy="53" tox="37" sentence="Is as Londain Shasana mé ó dhúchas (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="35" fromy="54" fromx="35" toy="54" tox="54" sentence="Mar chuid den socrú beidh Michelle ag labhairt Ghaeilge ag ócáidí poiblí." errortext="ag labhairt Ghaeilge" msg="Séimhiú gan ghá">
<E offset="50" fromy="55" fromx="50" toy="55" tox="51" sentence="Tá dún cosanta eile ar an taobh thoir den oileán (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="57" fromy="56" fromx="57" toy="56" tox="58" sentence="Déan teagmháil leis an Rannóg ag an seoladh thuasluaite (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="6" fromy="57" fromx="6" toy="57" tox="24" sentence="Tá na lachain slachtmhara ar eitilt." errortext="lachain slachtmhara" msg="Séimhiú ar iarraidh">
<E offset="53" fromy="58" fromx="53" toy="58" tox="54" sentence="Mhair cuid mhór dár sinsir céad caoga bliain ó shin (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="46" fromy="59" fromx="46" toy="59" tox="47" sentence="Tá sé le cloisteáil sna meáin gach seachtain (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="16" fromy="60" fromx="16" toy="60" tox="34" sentence="Déanann siad na breiseáin brabhsála don tionscal ríomhaireachta." errortext="breiseáin brabhsála" msg="Séimhiú ar iarraidh">
<E offset="6" fromy="61" fromx="6" toy="61" tox="14" sentence="Is ar éisc mara agus ar na hainmhithe mara eile atáimid ag díriú." errortext="éisc mara" msg="Séimhiú ar iarraidh">
<E offset="40" fromy="62" fromx="40" toy="62" tox="41" sentence="Chonaic mé líon agus crainn tógála ann (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="28" fromy="63" fromx="28" toy="63" tox="47" sentence="Bhí pictiúir le feiceáil ar scáileáin theilifíse ar fud an domhain." errortext="scáileáin theilifíse" msg="Séimhiú gan ghá">
<E offset="16" fromy="64" fromx="16" toy="64" tox="22" sentence="Maidin lá ar na mhárach thug a fhear gaoil cuairt air." errortext="mhárach" msg="Ní úsáidtear an focal seo ach san abairtín «arna mhárach» de ghnáth">
<E offset="10" fromy="65" fromx="10" toy="65" tox="13" sentence="Cad é mar a tá tú?" errortext="a tá" msg="Ba chóir duit «atá» a úsáid anseo">
<E offset="0" fromy="66" fromx="0" toy="66" tox="4" sentence="A aon, a dó, a trí." errortext="A aon" msg="Réamhlitir «h» ar iarraidh">
<E offset="56" fromy="67" fromx="56" toy="67" tox="57" sentence="Ba é a aon aidhm ar an saol daoine a ghnóthú don chúis (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="52" fromy="68" fromx="52" toy="68" tox="60" sentence="Tá an Rialtas tar éis áit na Gaeilge i saol na tíre a ceistiú." errortext="a ceistiú" msg="Séimhiú ar iarraidh">
<E offset="52" fromy="69" fromx="52" toy="69" tox="53" sentence="Ach sin scéal eile mar a déarfadh an té a déarfadh (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="46" fromy="70" fromx="46" toy="70" tox="47" sentence="Is iomaí uair a fuair mé locht ar an rialtas (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="53" fromy="71" fromx="53" toy="71" tox="60" sentence="Bhíodar ag rá ar an aonach gur agamsa a bhí na huain ab fearr." errortext="ab fearr" msg="Séimhiú ar iarraidh">
<E offset="10" fromy="72" fromx="10" toy="72" tox="22" sentence="Ní bheidh ach mhallacht i ndán dó ó na ciníocha agus fuath ó na náisiúin." errortext="ach mhallacht" msg="Séimhiú gan ghá">
<E offset="55" fromy="73" fromx="55" toy="73" tox="56" sentence="Ní theastaíonn uaithi ach bheith ina ball den chumann (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="29" fromy="74" fromx="29" toy="74" tox="40" sentence="An bhfuil aon uachtar reoite ar an cuntar?" errortext="ar an cuntar" msg="Urú nó séimhiú ar iarraidh">
<E offset="45" fromy="75" fromx="45" toy="75" tox="46" sentence="Baintear feidhm as chun aicídí súl a mhaolú (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="14" fromy="76" fromx="14" toy="76" tox="21" sentence="Má shuíonn tú ag bhord le flaith, tabhair faoi deara go cúramach céard atá leagtha romhat." errortext="ag bhord" msg="Séimhiú gan ghá">
<E offset="14" fromy="77" fromx="14" toy="77" tox="26" sentence="Bláthaíonn sé amhail bhláth an mhachaire." errortext="amhail bhláth" msg="Séimhiú gan ghá">
<E offset="0" fromy="78" fromx="0" toy="78" tox="7" sentence="An chuir an bhean bheag mórán ceisteanna ort?" errortext="An chuir" msg="Ba chóir duit «ar» a úsáid anseo">
<E offset="40" fromy="79" fromx="40" toy="79" tox="41" sentence="An ndeachaigh tú ag iascaireacht inniu (OK)?" errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="53" fromy="80" fromx="53" toy="80" tox="54" sentence="An raibh aon bhealach praiticiúil eile chun na hInd (OK)?" errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="0" fromy="81" fromx="0" toy="81" tox="8" sentence="An bainim sult as bás an drochdhuine?" errortext="An bainim" msg="Urú ar iarraidh">
<E offset="52" fromy="82" fromx="52" toy="82" tox="53" sentence="An éireodh níos fearr leo dá mba mar sin a bheidís (OK)?" errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="10" fromy="83" fromx="10" toy="83" tox="21" sentence="Ní féidir an Gaeltacht a choinneáil mar réigiún Gaeilge go náisiúnta gan athrú bunúsach." errortext="an Gaeltacht" msg="Séimhiú ar iarraidh">
<E offset="7" fromy="84" fromx="7" toy="84" tox="18" sentence="I gcás An Comhairle Ealaíon ní mór é seo a dhéanamh." errortext="An Comhairle" msg="Séimhiú ar iarraidh">
<E offset="0" fromy="85" fromx="0" toy="85" tox="6" sentence="An bean sin, tá sí ina múinteoir." errortext="An bean" msg="Séimhiú ar iarraidh">
<E offset="68" fromy="86" fromx="68" toy="86" tox="69" sentence="Chuala sé a mháthair ag labhairt chomh caoin seo leis an mbean nua (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="46" fromy="87" fromx="46" toy="87" tox="47" sentence="Chinn sé an cruinniú a chur ar an méar fhada (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="27" fromy="88" fromx="27" toy="88" tox="37" sentence="Cad é an chomhairle a thug an ochtapas dó?" errortext="an ochtapas" msg="Réamhlitir «t» ar iarraidh">
<E offset="0" fromy="89" fromx="0" toy="89" tox="6" sentence="An Acht um Chomhionannas Fostaíochta." errortext="An Acht" msg="Réamhlitir «t» ar iarraidh">
<E offset="38" fromy="90" fromx="38" toy="90" tox="39" sentence="Dath bánbhuí éadrom atá ar an adhmad (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="55" fromy="91" fromx="55" toy="91" tox="67" sentence="Chóirigh sé na lampaí le solas a chaitheamh os comhair an coinnleora." errortext="an coinnleora" msg="Séimhiú ar iarraidh">
<E offset="34" fromy="92" fromx="34" toy="92" tox="46" sentence="Comhlánóidh saoránacht an Aontais an saoránacht náisiúnta agus ní ghabhfaidh sí a hionad." errortext="an saoránacht" msg="Réamhlitir «t» ar iarraidh">
<E offset="14" fromy="93" fromx="14" toy="93" tox="24" sentence="Ní raibh guth an séiléara le clos a thuilleadh." errortext="an séiléara" msg="Réamhlitir «t» ar iarraidh">
<E offset="40" fromy="94" fromx="40" toy="94" tox="46" sentence="Tá sin ráite cheana féin acu le muintir an tíre seo." errortext="an tíre" msg="Ba chóir duit «na» a úsáid anseo">
<E offset="68" fromy="95" fromx="68" toy="95" tox="81" sentence="Is é is dóichí go raibh baint ag an eisimirce leis an laghdú i líon an gcainteoirí Gaeilge." errortext="an gcainteoirí" msg="Ba chóir duit «na» a úsáid anseo">
<E offset="7" fromy="96" fromx="7" toy="96" tox="12" sentence="Is iad an trí cholún le chéile an tAontas Eorpach." errortext="an trí" msg="Ba chóir duit «na» a úsáid anseo">
<E offset="57" fromy="97" fromx="57" toy="97" tox="58" sentence="Sheol an ceithre mhíle de na meirligh amach san fhásach (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="10" fromy="98" fromx="10" toy="98" tox="21" sentence="Ní bhíonn an dhíograis chéanna ná an dhúthracht chéanna i gceist." errortext="an dhíograis" msg="Urú nó séimhiú gan ghá">
<E offset="34" fromy="98" fromx="34" toy="98" tox="46" sentence="Ní bhíonn an dhíograis chéanna ná an dhúthracht chéanna i gceist." errortext="an dhúthracht" msg="Urú nó séimhiú gan ghá">
<E offset="5" fromy="99" fromx="5" toy="99" tox="24" sentence="Ba é an fear an phortaigh a tháinig thart leis na plátaí bia." errortext="an fear an phortaigh" msg="Ní gá leis an alt cinnte anseo">
<E offset="20" fromy="100" fromx="20" toy="100" tox="44" sentence="Tá dhá shiombail ag an bharr gach leathanaigh." errortext="an bharr gach leathanaigh" msg="Ní gá leis an alt cinnte anseo">
<E offset="0" fromy="101" fromx="0" toy="101" tox="9" sentence="An fhéidir le duine ar bith eile breathnú ar mo script?" errortext="An fhéidir" msg="Séimhiú gan ghá">
<E offset="10" fromy="102" fromx="10" toy="102" tox="16" sentence="Ní bhíonn aon dhá chlár as an chrann céanna mar a chéile go díreach." errortext="aon dhá" msg="Séimhiú gan ghá">
<E offset="10" fromy="103" fromx="10" toy="103" tox="22" sentence="Ní bheidh aon buntáiste againn orthu sin." errortext="aon buntáiste" msg="Séimhiú ar iarraidh">
<E offset="6" fromy="104" fromx="6" toy="104" tox="11" sentence="Rogha aon de na focail a tháinig i d'intinn." errortext="aon de" msg="Cor cainte aisteach">
<E offset="38" fromy="105" fromx="38" toy="105" tox="39" sentence="Ná hith aon arán gabhála mar aon léi (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="51" fromy="106" fromx="51" toy="106" tox="52" sentence="Freagair aon dá cheann ar bith díobh seo a leanas (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="42" fromy="107" fromx="42" toy="107" tox="50" sentence="Bhí daoine le fáil i Sasana a chreid gach ar dúradh sa bholscaireacht." errortext="ar dúradh" msg="Ba chóir duit «a, an» a úsáid anseo">
<E offset="36" fromy="108" fromx="36" toy="108" tox="42" sentence="Tá treoirlínte mionsonraithe curtha ar fail ag an gCoimisiún." errortext="ar fail" msg="Leanann séimhiú an réamhfhocal «ar» go minic, ach ní léir é sa chás seo">
<E offset="46" fromy="109" fromx="46" toy="109" tox="52" sentence="Bhí cead againn fanacht ag obair ar an talamh ar fead trí mhí." errortext="ar fead" msg="Leanann séimhiú an réamhfhocal «ar» go minic, ach ní léir é sa chás seo">
<E offset="55" fromy="110" fromx="55" toy="110" tox="56" sentence="Tá sé an chéad suíomh gréasán ar bronnadh teastas air (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="71" fromy="111" fromx="71" toy="111" tox="78" sentence="Bhíomar ag féachaint ar an Ghaeltacht mar ionad chun feabhas a chur ar ar gcuid Gaeilge." errortext="ar gcuid" msg="Leanann séimhiú an réamhfhocal «ar» go minic, ach ní léir é sa chás seo">
<E offset="14" fromy="112" fromx="14" toy="112" tox="19" sentence="Cosc a bheith ar cic a thabhairt don sliotar." errortext="ar cic" msg="Leanann séimhiú an réamhfhocal «ar» go minic, ach ní léir é sa chás seo">
<E offset="39" fromy="113" fromx="39" toy="113" tox="40" sentence="Cosc a bheith ar CIC leabhair a dhíol (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="41" fromy="114" fromx="41" toy="114" tox="42" sentence="Beidh cairde dá cuid ar Gaeilgeoirí iad (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="0" fromy="115" fromx="0" toy="115" tox="8" sentence="Ar gcaith tú do chiall agus do chéadfaí ar fad?" errortext="Ar gcaith" msg="Séimhiú ar iarraidh">
<E offset="10" fromy="116" fromx="10" toy="116" tox="21" sentence="Ní amháin ár dhá chosa, ach nigh ár lámha!" errortext="ár dhá chosa" msg="Urú ar iarraidh">
<E offset="48" fromy="117" fromx="48" toy="117" tox="55" sentence="Gheobhaimid maoin de gach sórt, agus líonfaimid ár tithe le creach." errortext="ár tithe" msg="Urú ar iarraidh">
<E offset="11" fromy="118" fromx="11" toy="118" tox="18" sentence="Níl aon ní arbh fiú a shantú seachas í." errortext="arbh fiú" msg="Séimhiú ar iarraidh">
<E offset="0" fromy="119" fromx="0" toy="119" tox="7" sentence="Ba maith liom fios a thabhairt anois daoibh." errortext="Ba maith" msg="Séimhiú ar iarraidh">
<E offset="16" fromy="120" fromx="16" toy="120" tox="24" sentence="Dúirt daoine go mba ceart an poll a dhúnadh suas ar fad." errortext="mba ceart" msg="Séimhiú ar iarraidh">
<E offset="0" fromy="121" fromx="0" toy="121" tox="5" sentence="Ba eol duit go hiomlán m'anam." errortext="Ba eol" msg="Ba chóir duit «b', ab» a úsáid anseo">
<E offset="7" fromy="122" fromx="7" toy="122" tox="21" sentence="D'fhan beirt buachaill sa champa." errortext="beirt buachaill" msg="Séimhiú ar iarraidh">
<E offset="7" fromy="123" fromx="7" toy="123" tox="31" sentence="D'fhan beirt bhuachaill cancrach sa champa." errortext="beirt bhuachaill cancrach" msg="Séimhiú ar iarraidh">
<E offset="48" fromy="124" fromx="48" toy="124" tox="49" sentence="Mothóidh Pobal Osraí an bheirt laoch sin uathu (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="10" fromy="125" fromx="10" toy="125" tox="23" sentence="Ní amháin bhur dhá chosa, ach nigh bhur lámha!" errortext="bhur dhá chosa" msg="Urú ar iarraidh">
<E offset="28" fromy="126" fromx="28" toy="126" tox="40" sentence="Déanaigí beart leis de réir bhur briathra." errortext="bhur briathra" msg="Urú ar iarraidh">
<E offset="0" fromy="127" fromx="0" toy="127" tox="7" sentence="Cé mhéid gealladh ar briseadh ar an Indiach bocht?" errortext="Cé mhéid" msg="Foirm neamhchaighdeánach de «mhéad»">
<E offset="24" fromy="128" fromx="24" toy="128" tox="38" sentence="Nach raibh a fhios aige cé mhéad daoine a bhíonn ag éisteacht leis an stáisiún." errortext="cé mhéad daoine" msg="Tá gá leis an leagan uatha anseo">
<E offset="12" fromy="129" fromx="12" toy="129" tox="27" sentence="Faigh amach cé mhéad salainn a bhíonn i sampla d'uisce." errortext="cé mhéad salainn" msg="Tá gá leis an leagan uatha anseo">
<E offset="0" fromy="130" fromx="0" toy="130" tox="5" sentence="Cá áit a nochtfadh sé é féin ach i mBostún!" errortext="Cá áit" msg="Réamhlitir «h» ar iarraidh">
<E offset="0" fromy="131" fromx="0" toy="131" tox="6" sentence="Cá chás dúinn bheith ag máinneáil thart anseo?" errortext="Cá chás" msg="Séimhiú gan ghá">
<E offset="35" fromy="132" fromx="35" toy="132" tox="36" sentence="Cá mhinice ba riachtanach dó stad (OK)?" errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="0" fromy="133" fromx="0" toy="133" tox="11" sentence="Cá n-oibrigh an t-údar sular imigh sí le ceol?" errortext="Cá n-oibrigh" msg="Ba chóir duit «cár» a úsáid anseo">
<E offset="27" fromy="134" fromx="27" toy="134" tox="28" sentence="Cá raibh na rudaí go léir (OK)?" errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="0" fromy="135" fromx="0" toy="135" tox="10" sentence="Cá cuireann tú do thréad ar féarach?" errortext="Cá cuireann" msg="Urú ar iarraidh">
<E offset="0" fromy="136" fromx="0" toy="136" tox="11" sentence="Cá úsáidfear an mhóin?" errortext="Cá úsáidfear" msg="Urú ar iarraidh">
<E offset="0" fromy="137" fromx="0" toy="137" tox="6" sentence="Cár fág tú eisean?" errortext="Cár fág" msg="Ba chóir duit «cá» a úsáid anseo">
<E offset="0" fromy="138" fromx="0" toy="138" tox="8" sentence="Cár bhfág tú eisean?" errortext="Cár bhfág" msg="Séimhiú ar iarraidh">
<E offset="19" fromy="139" fromx="19" toy="139" tox="20" sentence="Cár fágadh eisean (OK)?" errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="17" fromy="140" fromx="17" toy="140" tox="22" sentence="Sin é a dhéantar i gcas cuntair oibre cistine." errortext="i gcas" msg="Focal ceart ach aimsítear é níos minice in ionad «i gcás»">
<E offset="0" fromy="141" fromx="0" toy="141" tox="5" sentence="Cé iad na fir seo ag fanacht farat?" errortext="Cé iad" msg="Réamhlitir «h» ar iarraidh">
<E offset="29" fromy="142" fromx="29" toy="142" tox="30" sentence="Cé ea, rachaidh mé ann leat (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="0" fromy="143" fromx="0" toy="143" tox="4" sentence="Cé an ceart atá agamsa a thuilleadh fós a lorg ar an rí?" errortext="Cé an" msg="Ba chóir duit «cén» a úsáid anseo">
<E offset="15" fromy="144" fromx="15" toy="144" tox="29" sentence="D'fhoilsigh sí a céad cnuasach filíochta i 1995." errortext="a céad cnuasach" msg="Séimhiú ar iarraidh">
<E offset="20" fromy="145" fromx="20" toy="145" tox="32" sentence="Chuir siad fios orm ceithre uaire ar an tslí sin." errortext="ceithre uaire" msg="Ba chóir duit «huaire» a úsáid anseo">
<E offset="48" fromy="146" fromx="48" toy="146" tox="59" sentence="Beidh ar Bhord Feidhmiúcháin an tUachtarán agus ceithre ball eile." errortext="ceithre ball" msg="Séimhiú ar iarraidh">
<E offset="51" fromy="147" fromx="51" toy="147" tox="52" sentence="Tá sé tuigthe aige go bhfuil na ceithre dúile ann (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="0" fromy="148" fromx="0" toy="148" tox="11" sentence="Cén amhránaí is fearr leat?" errortext="Cén amhránaí" msg="Réamhlitir «t» ar iarraidh">
<E offset="0" fromy="149" fromx="0" toy="149" tox="6" sentence="Cén slí ar fhoghlaim tú an teanga?" errortext="Cén slí" msg="Réamhlitir «t» ar iarraidh">
<E offset="72" fromy="150" fromx="72" toy="150" tox="73" sentence="Cha dtug mé cur síos ach ar dhá bhabhta collaíochta san úrscéal ar fad (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="7" fromy="151" fromx="7" toy="151" tox="20" sentence="Bhí an chéad cruinniú den Choimisiún i Ros Muc i nGaeltacht na Gaillimhe." errortext="chéad cruinniú" msg="Séimhiú ar iarraidh">
<E offset="6" fromy="152" fromx="6" toy="152" tox="18" sentence="Tá sé chomh iontach le sneachta dearg." errortext="chomh iontach" msg="Réamhlitir «h» ar iarraidh">
<E offset="26" fromy="153" fromx="26" toy="153" tox="36" sentence="Chuir mé céad punta chuig an banaltra." errortext="an banaltra" msg="Séimhiú ar iarraidh">
<E offset="22" fromy="154" fromx="22" toy="154" tox="34" sentence="Níl tú do do sheoladh chuig dhaoine a labhraíonn teanga dhothuigthe." errortext="chuig dhaoine" msg="Séimhiú gan ghá">
<E offset="41" fromy="155" fromx="41" toy="155" tox="50" sentence="Seo deis iontach chun an Ghaeilge a chur chun chinn." errortext="chun chinn" msg="Séimhiú gan ghá">
<E offset="54" fromy="156" fromx="54" toy="156" tox="55" sentence="Tiocfaidh deontas faoin alt seo chun bheith iníoctha (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="34" fromy="157" fromx="34" toy="157" tox="39" sentence="D'éirídís ar maidin ar a ceathair a clog." errortext="a clog" msg="Séimhiú ar iarraidh">
<E offset="30" fromy="158" fromx="30" toy="158" tox="41" sentence="Bhí sé cúig bhanlámh ar fhad, cúig banlámh ar leithead." errortext="cúig banlámh" msg="Séimhiú ar iarraidh">
<E offset="17" fromy="159" fromx="17" toy="159" tox="28" sentence="Beirim mo mhionn dar an beart a rinne Dia le mo shinsir." errortext="dar an beart" msg="Urú nó séimhiú ar iarraidh">
<E offset="20" fromy="160" fromx="20" toy="160" tox="35" sentence="Sa dara bliain déag dár braighdeanas, tháinig fear ar a theitheadh." errortext="dár braighdeanas" msg="Urú ar iarraidh">
<E offset="25" fromy="161" fromx="25" toy="161" tox="32" sentence="D'oibrigh mé liom go dtí Dé Aoine." errortext="Dé Aoine" msg="Réamhlitir «h» ar iarraidh">
<E offset="24" fromy="162" fromx="24" toy="162" tox="28" sentence="Míle naoi gcéad a hocht ndéag is fiche." errortext="ndéag" msg="Foirm neamhchaighdeánach de «déag»">
<E offset="21" fromy="163" fromx="21" toy="163" tox="30" sentence="Feicim go bhfuil aon duine déag curtha san uaigh seo." errortext="duine déag" msg="Séimhiú ar iarraidh">
<E offset="69" fromy="164" fromx="69" toy="164" tox="70" sentence="D'fhás sé ag deireadh na naoú haoise déag agus fás an náisiúnachais (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="53" fromy="165" fromx="53" toy="165" tox="61" sentence="Tabharfaidh an tUachtarán a óráid ag leath i ndiaidh a dó déag Dé Sathairn." errortext="a dó déag" msg="Ní úsáidtear an focal seo ach san abairtín «a dó dhéag, dhá X déag» de ghnáth">
<E offset="15" fromy="166" fromx="15" toy="166" tox="25" sentence="Bhuail an clog a trí dhéag." errortext="a trí dhéag" msg="Ní úsáidtear an focal seo ach san abairtín «a trí déag, trí X déag» de ghnáth">
<E offset="3" fromy="167" fromx="3" toy="167" tox="10" sentence="Tá trí déag litir san fhocal seo." errortext="trí déag" msg="Ní úsáidtear an focal seo ach san abairtín «a trí déag, trí X déag» de ghnáth">
<E offset="4" fromy="168" fromx="4" toy="168" tox="14" sentence="Bhí deich tobar fíoruisce agus seachtó crann pailme ann." errortext="deich tobar" msg="Urú ar iarraidh">
<E offset="12" fromy="169" fromx="12" toy="169" tox="24" sentence="Tógfaidh mé do coinnleoir óna ionad, mura ndéana tú aithrí." errortext="do coinnleoir" msg="Séimhiú ar iarraidh">
<E offset="13" fromy="170" fromx="13" toy="170" tox="21" sentence="Is cúis imní don pobal a laghad maoinithe a dhéantar ar Naíscoileanna." errortext="don pobal" msg="Séimhiú ar iarraidh">
<E offset="27" fromy="171" fromx="27" toy="171" tox="36" sentence="Daoine eile atá ina mbaill den dhream seo." errortext="den dhream" msg="Urú nó séimhiú gan ghá">
<E offset="25" fromy="172" fromx="25" toy="172" tox="35" sentence="Creidim go raibh siad de an thuairim chéanna." errortext="an thuairim" msg="Urú nó séimhiú gan ghá">
<E offset="3" fromy="173" fromx="3" toy="173" tox="12" sentence="Tá dhá teanga oifigiúla le stádas bunreachtúil á labhairt sa tír seo." errortext="dhá teanga" msg="Séimhiú ar iarraidh">
<E offset="0" fromy="174" fromx="0" toy="174" tox="10" sentence="Dhá fiacail lárnacha i ngach aon chomhla." errortext="Dhá fiacail" msg="Séimhiú ar iarraidh">
<E offset="19" fromy="175" fromx="19" toy="175" tox="30" sentence="Rug sí greim ar mo dhá gualainn agus an fhearg a bhí ina súile." errortext="dhá gualainn" msg="Séimhiú ar iarraidh">
<E offset="28" fromy="176" fromx="28" toy="176" tox="29" sentence="Bhí Eibhlín ar a dhá glúin (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="20" fromy="177" fromx="20" toy="177" tox="25" sentence="Is léir nach bhfuil an dhá theanga ar chomhchéim lena chéile." errortext="an dhá" msg="Séimhiú gan ghá">
<E offset="13" fromy="178" fromx="13" toy="178" tox="21" sentence="Tionóladh an chéad dhá chomórtas i nGaoth Dobhair." errortext="chéad dhá" msg="Séimhiú gan ghá">
<E offset="43" fromy="179" fromx="43" toy="179" tox="47" sentence="Cá bhfuil feoil le fáil agamsa le tabhairt do an mhuintir?" errortext="do an" msg="Ba chóir duit «don» a úsáid anseo">
<E offset="44" fromy="180" fromx="44" toy="180" tox="56" sentence="Is amhlaidh a bheidh freisin do na tagairtí do airteagail." errortext="do airteagail" msg="Ba chóir duit «d+uaschamóg» a úsáid anseo">
<E offset="40" fromy="181" fromx="40" toy="181" tox="43" sentence="Tá sé de chúram seirbhís a chur ar fáil do a chustaiméirí i nGaeilge." errortext="do a" msg="Ba chóir duit «dá» a úsáid anseo">
<E offset="29" fromy="182" fromx="29" toy="182" tox="33" sentence="Seinnigí moladh ar an gcruit do ár máthair." errortext="do ár" msg="Ba chóir duit «dár» a úsáid anseo">
<E offset="27" fromy="183" fromx="27" toy="183" tox="31" sentence="Is é seo mo Mhac muirneach do ar thug mé gnaoi." errortext="do ar" msg="Ba chóir duit «dár» a úsáid anseo">
<E offset="21" fromy="184" fromx="21" toy="184" tox="35" sentence="Tá an domhan go léir faoi suaimhneas." errortext="faoi suaimhneas" msg="Séimhiú ar iarraidh">
<E offset="59" fromy="185" fromx="59" toy="185" tox="65" sentence="Caithfidh pobal na Gaeltachta iad féin cinneadh a dhéanamh faoi an Ghaeilge." errortext="faoi an" msg="Ba chóir duit «faoin» a úsáid anseo">
<E offset="31" fromy="186" fromx="31" toy="186" tox="36" sentence="Cuireann sí a neart mar chrios faoi a coim." errortext="faoi a" msg="Ba chóir duit «faoina» a úsáid anseo">
<E offset="21" fromy="187" fromx="21" toy="187" tox="27" sentence="Cuireann sé ciníocha faoi ár smacht agus cuireann sé náisiúin faoinár gcosa." errortext="faoi ár" msg="Ba chóir duit «faoinár» a úsáid anseo">
<E offset="41" fromy="188" fromx="41" toy="188" tox="51" sentence="Tá dualgas ar an gComhairle sin tabhairt faoin cúram seo." errortext="faoin cúram" msg="Urú nó séimhiú ar iarraidh">
<E offset="17" fromy="189" fromx="17" toy="189" tox="33" sentence="Tugadh mioneolas faoin dtionscnamh seo in Eagrán a haon." errortext="faoin dtionscnamh" msg="Urú nó séimhiú gan ghá">
<E offset="25" fromy="190" fromx="25" toy="190" tox="38" sentence="Bhí lúcháir ar an Tiarna faoina dhearna sé!" errortext="faoina dhearna" msg="Urú ar iarraidh">
<E offset="56" fromy="191" fromx="56" toy="191" tox="68" sentence="Ní bheidh gearán ag duine ar bith faoin gciste fial atá faoinár cúram." errortext="faoinár cúram" msg="Urú ar iarraidh">
<E offset="16" fromy="192" fromx="16" toy="192" tox="30" sentence="Beidh paráid Lá Fhéile Phádraig i mBostún." errortext="Fhéile Phádraig" msg="Séimhiú gan ghá">
<E offset="62" fromy="193" fromx="62" toy="193" tox="63" sentence="Tá Féile Bhealtaine an Oireachtais ar siúl an tseachtain seo (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="21" fromy="194" fromx="21" toy="194" tox="41" sentence="Fágtar na mílte eile gan ghéaga nó radharc na súl." errortext="gan ghéaga nó radharc" msg="Ba chóir duit «ná» a úsáid anseo">
<E offset="47" fromy="195" fromx="47" toy="195" tox="57" sentence="Tá ar chumas an duine saol iomlán a chaitheamh gan theanga eile á brú air." errortext="gan theanga" msg="Séimhiú gan ghá">
<E offset="19" fromy="196" fromx="19" toy="196" tox="30" sentence="Tá gruaim mhór orm gan Chaitlín." errortext="gan Chaitlín" msg="Séimhiú gan ghá">
<E offset="37" fromy="197" fromx="37" toy="197" tox="45" sentence="Deir daoine eile, áfach, gur dailtín gan maith é." errortext="gan maith" msg="Leanann séimhiú an réamhfhocal «gan» go minic, ach ní léir é sa chás seo">
<E offset="42" fromy="198" fromx="42" toy="198" tox="52" sentence="Fuarthas an fear marbh ar an trá, a chorp gan máchail gan ghortú." errortext="gan máchail" msg="Leanann séimhiú an réamhfhocal «gan» go minic, ach ní léir é sa chás seo">
<E offset="26" fromy="199" fromx="26" toy="199" tox="27" sentence="Dúirt sé liom gan pósadh (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="74" fromy="200" fromx="74" toy="200" tox="75" sentence="Na duilleoga ar an ngas beag, cruth lansach orthu agus iad gan cos fúthu (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="52" fromy="201" fromx="52" toy="201" tox="53" sentence="D'fhág sin gan meas dá laghad ag duine ar bith air (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="24" fromy="202" fromx="24" toy="202" tox="25" sentence="Tá mé gan cos go brách (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="65" fromy="203" fromx="65" toy="203" tox="66" sentence="Níl sé ceadaithe aistriú ó rang go chéile gan cead a fháil uaim (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="67" fromy="204" fromx="67" toy="204" tox="78" sentence="Is stáit ilteangacha iad cuid mhór de na stáit sin atá aonteangach go oifigiúil." errortext="go oifigiúil" msg="Réamhlitir «h» ar iarraidh">
<E offset="30" fromy="205" fromx="30" toy="205" tox="37" sentence="Ní bheidh bonn comparáide ann go beidh torthaí Dhaonáireamh 2007 ar fáil." errortext="go beidh" msg="Urú ar iarraidh">
<E offset="17" fromy="206" fromx="17" toy="206" tox="25" sentence="Rug sé ar ais mé go dhoras an Teampaill." errortext="go dhoras" msg="Séimhiú gan ghá">
<E offset="61" fromy="207" fromx="61" toy="207" tox="62" sentence="Tiocfaidh coimhlintí chun tosaigh sa Chumann ó am go chéile (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="82" fromy="208" fromx="82" toy="208" tox="83" sentence="Is turas iontach é an turas ó bheith i do thosaitheoir go bheith i do mhúinteoir (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="54" fromy="209" fromx="54" toy="209" tox="55" sentence="Tá a chuid leabhar tiontaithe go dhá theanga fichead (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="16" fromy="210" fromx="16" toy="210" tox="20" sentence="Chuaigh mé suas go an doras cúil a chaisleáin." errortext="go an" msg="Ba chóir duit «go dtí» a úsáid anseo">
<E offset="23" fromy="211" fromx="23" toy="211" tox="27" sentence="Tháinig Pól Ó Coileáin go mo theach ar maidin." errortext="go mo" msg="Ba chóir duit «go dtí» a úsáid anseo">
<E offset="28" fromy="212" fromx="28" toy="212" tox="39" sentence="Bhí an teachtaireacht dulta go m'inchinn." errortext="go m'inchinn" msg="Ba chóir duit «go dtí» a úsáid anseo">
<E offset="12" fromy="213" fromx="12" toy="213" tox="23" sentence="Tar, téanam go dtí bhean na bhfíseanna." errortext="go dtí bhean" msg="Séimhiú gan ghá">
<E offset="60" fromy="214" fromx="60" toy="214" tox="61" sentence="Agus rachaidh mé siar go dtí thú tráthnóna, más maith leat (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="15" fromy="215" fromx="15" toy="215" tox="26" sentence="Ba mhaith liom gur bhfágann daoine óga an scoil agus iad ullmhaithe." errortext="gur bhfágann" msg="Ba chóir duit «go» a úsáid anseo">
<E offset="11" fromy="216" fromx="11" toy="216" tox="19" sentence="Bhraith mé gur fuair mé boladh trom tais uathu." errortext="gur fuair" msg="Ba chóir duit «go» a úsáid anseo">
<E offset="20" fromy="217" fromx="20" toy="217" tox="28" sentence="An ea nach cás leat gur bhfág mo dheirfiúr an freastal fúmsa i m'aonar?" errortext="gur bhfág" msg="Séimhiú ar iarraidh">
<E offset="10" fromy="218" fromx="10" toy="218" tox="20" sentence="B'fhéidir gurbh fearr é seo duit ná leamhnacht na bó ba mhilse i gcontae Chill Mhantáin." errortext="gurbh fearr" msg="Séimhiú ar iarraidh">
<E offset="8" fromy="219" fromx="8" toy="219" tox="18" sentence="Tá ainm i n-easnamh a mbeadh coinne agat leis." errortext="i n-easnamh" msg="Ba chóir duit «in» a úsáid anseo">
<E offset="8" fromy="220" fromx="8" toy="220" tox="16" sentence="Tá ainm i easnamh a mbeadh coinne agat leis." errortext="i easnamh" msg="Ba chóir duit «in» a úsáid anseo">
<E offset="34" fromy="221" fromx="34" toy="221" tox="44" sentence="An bhfuil aon uachtar reoite agat i cuisneoir?" errortext="i cuisneoir" msg="Urú ar iarraidh">
<E offset="34" fromy="222" fromx="34" toy="222" tox="45" sentence="An bhfuil aon uachtar reoite agat i chuisneoir?" errortext="i chuisneoir" msg="Urú ar iarraidh">
<E offset="30" fromy="223" fromx="30" toy="223" tox="35" sentence="Táimid ag lorg 200 Club Gailf i gach cearn d'Éirinn." errortext="i gach" msg="Urú ar iarraidh">
<E offset="36" fromy="224" fromx="36" toy="224" tox="41" sentence="An bhfuil aon uachtar reoite agaibh i bhur mála?" errortext="i bhur" msg="Ba chóir duit «in bhur» a úsáid anseo">
<E offset="34" fromy="225" fromx="34" toy="225" tox="38" sentence="An bhfuil aon uachtar reoite agat i dhá chuisneoir?" errortext="i dhá" msg="Ba chóir duit «in dhá» a úsáid anseo">
<E offset="38" fromy="226" fromx="38" toy="226" tox="47" sentence="Bhí slám de pháipéar tais ag cruinniú i mhullach a chéile." errortext="i mhullach" msg="Séimhiú gan ghá">
<E offset="39" fromy="227" fromx="39" toy="227" tox="40" sentence="Fuair Derek Bell bás tobann i Phoenix (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="57" fromy="228" fromx="57" toy="228" tox="58" sentence="Tá níos mó ná 8500 múinteoir ann i thart faoi 540 scoil (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="34" fromy="229" fromx="34" toy="229" tox="37" sentence="An bhfuil aon uachtar reoite agat i an chuisneoir?" errortext="i an" msg="Ba chóir duit «sa» a úsáid anseo">
<E offset="34" fromy="230" fromx="34" toy="230" tox="37" sentence="An bhfuil aon uachtar reoite agat i na cuisneoirí?" errortext="i na" msg="Ba chóir duit «sna» a úsáid anseo">
<E offset="29" fromy="231" fromx="29" toy="231" tox="31" sentence="An bhfuil aon uachtar reoite i a cuisneoir?" errortext="i a" msg="Ba chóir duit «ina» a úsáid anseo">
<E offset="23" fromy="232" fromx="23" toy="232" tox="25" sentence="Roghnaigh na teangacha i a nochtar na leathanaigh seo." errortext="i a" msg="Ba chóir duit «ina» a úsáid anseo">
<E offset="36" fromy="233" fromx="36" toy="233" tox="39" sentence="Rinne gach cine é sin sna cathracha i ar lonnaíodar." errortext="i ar" msg="Ba chóir duit «inar» a úsáid anseo">
<E offset="29" fromy="234" fromx="29" toy="234" tox="32" sentence="An bhfuil aon uachtar reoite i ár mála?" errortext="i ár" msg="Ba chóir duit «inár» a úsáid anseo">
<E offset="30" fromy="235" fromx="30" toy="235" tox="34" sentence="Thug sé seo deis dom breathnú in mo thimpeall." errortext="in mo" msg="Ba chóir duit «i» a úsáid anseo">
<E offset="40" fromy="236" fromx="40" toy="236" tox="46" sentence="Phós sí Pádraig, fear ón mBlascaod Mór, in 1982." errortext="in 1982" msg="Ba chóir duit «i» a úsáid anseo">
<E offset="49" fromy="237" fromx="49" toy="237" tox="50" sentence="Phós sí Pádraig, fear ón mBlascaod Mór, in 1892 (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="52" fromy="238" fromx="52" toy="238" tox="53" sentence="Theastaigh uaibh beirt bheith in bhur scríbhneoirí (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="41" fromy="239" fromx="41" toy="239" tox="42" sentence="Beidh an spórt seo á imirt in dhá ionad (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="33" fromy="240" fromx="33" toy="240" tox="45" sentence="Cad é an rud is mó faoi na Gaeil ina chuireann sé suim?" errortext="ina chuireann" msg="Urú ar iarraidh">
<E offset="12" fromy="241" fromx="12" toy="241" tox="25" sentence="Tá beirfean inár craiceann faoi mar a bheimis i sorn." errortext="inár craiceann" msg="Urú ar iarraidh">
<E offset="51" fromy="242" fromx="51" toy="242" tox="61" sentence="Is tuar dóchais é an méid dul chun cinn atá déanta le bhlianta beaga." errortext="le bhlianta" msg="Séimhiú gan ghá">
<E offset="42" fromy="243" fromx="42" toy="243" tox="43" sentence="Leanaigí oraibh le bhur ndílseacht dúinn (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="66" fromy="244" fromx="66" toy="244" tox="67" sentence="Baineann an scéim le thart ar 28,000 miondíoltóir ar fud na tíre (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="74" fromy="245" fromx="74" toy="245" tox="75" sentence="Níor cuireadh aon tine síos, ar ndóigh, le chomh breá is a bhí an aimsir (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="36" fromy="246" fromx="36" toy="246" tox="37" sentence="Tá sí ag teacht le thú a fheiceáil (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="39" fromy="247" fromx="39" toy="247" tox="43" sentence="D'fhéadfadh tábhacht a bheith ag baint le an gcéad toisc díobh sin." errortext="le an" msg="Ba chóir duit «leis an» a úsáid anseo">
<E offset="50" fromy="248" fromx="50" toy="248" tox="54" sentence="Molann an Coimisiún go maoineofaí scéim chun tacú le na pobail." errortext="le na" msg="Ba chóir duit «leis na» a úsáid anseo">
<E offset="34" fromy="249" fromx="34" toy="249" tox="37" sentence="Labhraíodh gach duine an fhírinne le a chomharsa." errortext="le a" msg="Ba chóir duit «lena» a úsáid anseo">
<E offset="40" fromy="250" fromx="40" toy="250" tox="43" sentence="Le halt 16 i ndáil le hiarratas ar ordú le a meastar gur tugadh toiliú." errortext="le a" msg="Ba chóir duit «lena» a úsáid anseo">
<E offset="28" fromy="251" fromx="28" toy="251" tox="32" sentence="Beir i do láimh ar an tslat le ar bhuail tú an abhainn, agus seo leat." errortext="le ar" msg="Ba chóir duit «lenar» a úsáid anseo">
<E offset="35" fromy="252" fromx="35" toy="252" tox="39" sentence="Ba mhaith liom buíochas a ghlacadh le ár seirbhís riaracháin." errortext="le ár" msg="Ba chóir duit «lenár» a úsáid anseo">
<E offset="20" fromy="253" fromx="20" toy="253" tox="25" sentence="Tógann siad cuid de le iad féin a théamh." errortext="le iad" msg="Réamhlitir «h» ar iarraidh">
<E offset="32" fromy="254" fromx="32" toy="254" tox="42" sentence="Tá do scrios chomh leathan leis an farraige." errortext="an farraige" msg="Séimhiú ar iarraidh">
<E offset="14" fromy="255" fromx="14" toy="255" tox="25" sentence="Cuir alt eile lenar bhfuil scríofa agat i gCeist a trí." errortext="lenar bhfuil" msg="Ba chóir duit «lena» a úsáid anseo">
<E offset="26" fromy="256" fromx="26" toy="256" tox="36" sentence="Is linne í ar ndóigh agus lenár clann." errortext="lenár clann" msg="Urú ar iarraidh">
<E offset="0" fromy="257" fromx="0" toy="257" tox="8" sentence="Má tugann rí breith ar na boicht le cothromas, bunófar a ríchathaoir go brách." errortext="Má tugann" msg="Séimhiú ar iarraidh">
<E offset="38" fromy="258" fromx="38" toy="258" tox="39" sentence="Má deirim libh é, ní chreidfidh sibh (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="52" fromy="259" fromx="52" toy="259" tox="53" sentence="Má tá suim agat sa turas seo, seol d'ainm chugamsa (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="36" fromy="260" fromx="36" toy="260" tox="37" sentence="Má fuair níor fhreagair sé an facs (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="28" fromy="261" fromx="28" toy="261" tox="37" sentence="Roghnaítear an bhliain 1961 mar pointe tosaigh don anailís." errortext="mar pointe" msg="Séimhiú ar iarraidh">
<E offset="13" fromy="262" fromx="13" toy="262" tox="25" sentence="Aithnítear é mar an údarás." errortext="mar an údarás" msg="Réamhlitir «t» ar iarraidh">
<E offset="0" fromy="263" fromx="0" toy="263" tox="8" sentence="Más mhian leat tuilleadh eolais a fháil, scríobh chugainn." errortext="Más mhian" msg="Séimhiú gan ghá">
<E offset="30" fromy="264" fromx="30" toy="264" tox="33" sentence="Tá caitheamh na hola ag dul i méad i gcónaí." errortext="méad" msg="Foirm neamhchaighdeánach de «méid, mhéid»">
<E offset="61" fromy="265" fromx="61" toy="265" tox="74" sentence="Tosaíodh ar mhodh adhlactha eile ina mbaintí úsáid as clocha measartha móra." errortext="measartha móra" msg="Tá gá leis an leagan uatha anseo">
<E offset="9" fromy="266" fromx="9" toy="266" tox="20" sentence="Comhlíon mo aitheanta agus mairfidh tú beo." errortext="mo aitheanta" msg="Ba chóir duit «m+uaschamóg» a úsáid anseo">
<E offset="15" fromy="267" fromx="15" toy="267" tox="26" sentence="Ceapadh mise i mo bolscaire." errortext="mo bolscaire" msg="Séimhiú ar iarraidh">
<E offset="37" fromy="268" fromx="37" toy="268" tox="45" sentence="Tá mé ag sclábhaíocht ag iarraidh mo dhá gasúr a chur trí scoil." errortext="dhá gasúr" msg="Séimhiú ar iarraidh">
<E offset="15" fromy="269" fromx="15" toy="269" tox="35" sentence="Agus anois bhí mórsheisear iníonacha ag an sagart." errortext="mórsheisear iníonacha" msg="Tá gá leis an leagan uatha anseo">
<E offset="0" fromy="270" fromx="0" toy="270" tox="9" sentence="Mura dtuig siad é, nach dóibh féin is mó náire?" errortext="Mura dtuig" msg="Ba chóir duit «murar» a úsáid anseo">
<E offset="35" fromy="271" fromx="35" toy="271" tox="36" sentence="Mura bhfuair, sin an chraobh aige (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="0" fromy="272" fromx="0" toy="272" tox="10" sentence="Mura tagann aon duine i gcabhair orainn, rachaimid anonn chugaibh." errortext="Mura tagann" msg="Urú ar iarraidh">
<E offset="4" fromy="273" fromx="4" toy="273" tox="15" sentence="Fiú mura éiríonn liom, beidh mé ábalta cabhrú ar bhonn deonach." errortext="mura éiríonn" msg="Urú ar iarraidh">
<E offset="73" fromy="274" fromx="73" toy="274" tox="74" sentence="Murach bheith mar sin, bheadh sé dodhéanta dó oibriú na huaireanta fada (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="0" fromy="275" fromx="0" toy="275" tox="17" sentence="Murar chruthaítear lá agus oíche... teilgim uaim sliocht Iacóib." errortext="Murar chruthaítear" msg="Ba chóir duit «mura» a úsáid anseo">
<E offset="0" fromy="276" fromx="0" toy="276" tox="15" sentence="Murar gcruthaigh mise lá agus oíche... teilgim uaim sliocht Iacóib." errortext="Murar gcruthaigh" msg="Séimhiú ar iarraidh">
<E offset="37" fromy="277" fromx="37" toy="277" tox="42" sentence="An bhfuil aon uachtar reoite ag fear na bád?" errortext="na bád" msg="Urú ar iarraidh">
<E offset="18" fromy="278" fromx="18" toy="278" tox="27" sentence="Is mór ag náisiún na Éireann a choibhneas speisialta le daoine de bhunadh na hÉireann atá ina gcónaí ar an gcoigríoch." errortext="na Éireann" msg="Réamhlitir «h» ar iarraidh">
<E offset="44" fromy="279" fromx="44" toy="279" tox="58" sentence="Chuir an Coimisiún féin comhfhreagras chuig na eagraíochtaí seo ag lorg eolais faoina ngníomhaíochtaí." errortext="na eagraíochtaí" msg="Réamhlitir «h» ar iarraidh">
<E offset="35" fromy="280" fromx="35" toy="280" tox="49" sentence="Tá an tréith sin coitianta i measc na nÉireannaigh sa tír seo." errortext="na nÉireannaigh" msg="Tá gá leis an leagan ginideach anseo">
<E offset="12" fromy="281" fromx="12" toy="281" tox="21" sentence="Athdhéantar na snáithe i ngach ceann de na curaclaim seo." errortext="na snáithe" msg="Ba chóir duit «an» a úsáid anseo">
<E offset="0" fromy="282" fromx="0" toy="282" tox="10" sentence="Ná iompaígí chun na n-íol, agus ná dealbhaígí déithe de mhiotal." errortext="Ná iompaígí" msg="Réamhlitir «h» ar iarraidh">
<E offset="55" fromy="283" fromx="55" toy="283" tox="56" sentence="Tá tú níos faide sa tír ná is dleathach duit a bheith (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="44" fromy="284" fromx="44" toy="284" tox="45" sentence="Ach ní sin an cultúr a bhí ná atá go fóill (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="14" fromy="285" fromx="14" toy="285" tox="22" sentence="Agus creid nó ná chreid, nach bhfuil an lámhscríbhinn agam féin." errortext="ná chreid" msg="Séimhiú gan ghá">
<E offset="34" fromy="286" fromx="34" toy="286" tox="40" sentence="Níor thúisce greim bia caite aige ná thug sé an tuath air féin." errortext="ná thug" msg="Séimhiú gan ghá">
<E offset="43" fromy="287" fromx="43" toy="287" tox="50" sentence="Is fearr de bhéile luibheanna agus grá leo ná mhart méith agus gráin leis." errortext="ná mhart" msg="Séimhiú gan ghá">
<E offset="41" fromy="288" fromx="41" toy="288" tox="42" sentence="Is fearr an bás ná bheith beo ar dhéirc (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="32" fromy="289" fromx="32" toy="289" tox="33" sentence="Nach raibh dóthain eolais aige (OK)?" errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="0" fromy="290" fromx="0" toy="290" tox="12" sentence="Nach bainfidh mé uaidh an méid a ghoid sé uaim?" errortext="Nach bainfidh" msg="Urú ar iarraidh">
<E offset="0" fromy="291" fromx="0" toy="291" tox="10" sentence="Nach ghasta a fuair tú í!" errortext="Nach ghasta" msg="Séimhiú gan ghá">
<E offset="23" fromy="292" fromx="23" toy="292" tox="33" sentence="Rinneadh an roinnt don naoi treibh go leith ar chrainn." errortext="naoi treibh" msg="Urú ar iarraidh">
<E offset="44" fromy="293" fromx="44" toy="293" tox="57" sentence="Tháinig na bróga chomh fada siar le haimsir Naomh Phádraig féin." errortext="Naomh Phádraig" msg="Séimhiú gan ghá">
<E offset="0" fromy="294" fromx="0" toy="294" tox="7" sentence="Nár breá liom claíomh a bheith agam i mo ghlac!" errortext="Nár breá" msg="Séimhiú ar iarraidh">
<E offset="0" fromy="295" fromx="0" toy="295" tox="13" sentence="Nár bhfreagair sé thú, focal ar fhocal." errortext="Nár bhfreagair" msg="Séimhiú ar iarraidh">
<E offset="43" fromy="296" fromx="43" toy="296" tox="54" sentence="Feicimid gur de dheasca a n-easumhlaíochta nárbh féidir leo dul isteach ann." errortext="nárbh féidir" msg="Séimhiú ar iarraidh">
<E offset="0" fromy="297" fromx="0" toy="297" tox="12" sentence="Ní fuaireamar puinn eile tuairisce air i ndiaidh sin." errortext="Ní fuaireamar" msg="Urú ar iarraidh">
<E offset="0" fromy="298" fromx="0" toy="298" tox="12" sentence="Ní chuireadar aon áthas ar Mhac Dara." errortext="Ní chuireadar" msg="Ba chóir duit «níor» a úsáid anseo">
<E offset="34" fromy="299" fromx="34" toy="299" tox="35" sentence="Ní dúirt sé cad a bhí déanta acu (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="0" fromy="300" fromx="0" toy="300" tox="11" sentence="Ní féadfaidh a gcuid airgid ná óir iad a shábháil." errortext="Ní féadfaidh" msg="Séimhiú ar iarraidh">
<E offset="34" fromy="301" fromx="34" toy="301" tox="35" sentence="Ní bhfaighidh tú aon déirce uaim (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="33" fromy="302" fromx="33" toy="302" tox="34" sentence="Ní deir sé é seo le haon ghráin (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="0" fromy="303" fromx="0" toy="303" tox="5" sentence="Ní iad sin do phíopaí ar an tábla!" errortext="Ní iad" msg="Réamhlitir «h» ar iarraidh">
<E offset="0" fromy="304" fromx="0" toy="304" tox="11" sentence="Ní dheireadh aon duine acu aon rud liom." errortext="Ní dheireadh" msg="Séimhiú gan ghá">
<E offset="0" fromy="305" fromx="0" toy="305" tox="9" sentence="Ní fhéidir dóibh duine a shaoradh ón mbás." errortext="Ní fhéidir" msg="Séimhiú gan ghá">
<E offset="23" fromy="306" fromx="23" toy="306" tox="26" sentence="Bhí an méid sin airgid níba luachmhar dúinn ná maoin an domhain." errortext="níba" msg="Ba chóir duit an bhreischéim a úsáid anseo">
<E offset="27" fromy="307" fromx="27" toy="307" tox="31" sentence="An raibh duine ar bith acu ní ba bhocht ná eisean?" errortext="ní ba" msg="Ba chóir duit an bhreischéim a úsáid anseo">
<E offset="14" fromy="308" fromx="14" toy="308" tox="16" sentence="Eisean beagán níb óga ná mise." errortext="níb" msg="Ba chóir duit an bhreischéim a úsáid anseo">
<E offset="14" fromy="309" fromx="14" toy="309" tox="22" sentence="Eisean beagán níba óige ná mise." errortext="níba óige" msg="Ba chóir duit «níb» a úsáid anseo">
<E offset="22" fromy="310" fromx="22" toy="310" tox="32" sentence="Bhí na páistí ag éirí níba tréine." errortext="níba tréine" msg="Séimhiú ar iarraidh">
<E offset="35" fromy="311" fromx="20" toy="311" tox="32" sentence="&quot;Tá,&quot; ar sise, &quot;ach níor fhacthas é sin.&quot;" errortext="níor fhacthas" msg="Ba chóir duit «ní» a úsáid anseo">
<E offset="0" fromy="312" fromx="0" toy="312" tox="6" sentence="Níor gá do dheoraí riamh codladh sa tsráid; Bhí mo dhoras riamh ar leathadh." errortext="Níor gá" msg="Séimhiú ar iarraidh">
<E offset="35" fromy="313" fromx="20" toy="313" tox="29" sentence="&quot;Tá,&quot; ar sise, &quot;ach níor fuair muid aon ocras fós." errortext="níor fuair" msg="Ba chóir duit «ní» a úsáid anseo">
<E offset="0" fromy="314" fromx="0" toy="314" tox="9" sentence="Níor mbain sé leis an dream a bhí i gcogar ceilge." errortext="Níor mbain" msg="Séimhiú ar iarraidh">
<E offset="0" fromy="315" fromx="0" toy="315" tox="12" sentence="Níorbh foláir dó éisteacht a thabhairt dom." errortext="Níorbh foláir" msg="Séimhiú ar iarraidh">
<E offset="16" fromy="316" fromx="16" toy="316" tox="28" sentence="Tá bonn i bhfad níos dhoimhne ná sin le Féilte an Oireachtais." errortext="níos dhoimhne" msg="Séimhiú gan ghá">
<E offset="7" fromy="317" fromx="7" toy="317" tox="15" sentence="Eoghan Ó Anluain a thabharfaidh léacht deiridh na comhdhála." errortext="Ó Anluain" msg="Réamhlitir «h» ar iarraidh">
<E offset="10" fromy="318" fromx="10" toy="318" tox="19" sentence="Ach anois ó cuimhním air, bhí ardán coincréite sa pháirc." errortext="ó cuimhním" msg="Séimhiú ar iarraidh">
<E offset="57" fromy="319" fromx="57" toy="319" tox="58" sentence="Bhuel, fan ar strae mar sin ó tá tú chomh mímhúinte sin (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="57" fromy="320" fromx="57" toy="320" tox="58" sentence="Ní maith liom é ar chor ar bith ó fuair sé an litir sin (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="29" fromy="321" fromx="29" toy="321" tox="34" sentence="Tabhair an t-ordú seo leanas ó béal." errortext="ó béal" msg="Séimhiú ar iarraidh">
<E offset="21" fromy="322" fromx="21" toy="322" tox="24" sentence="Bíodh bhur ngrá saor ó an chur i gcéill." errortext="ó an" msg="Ba chóir duit «ón» a úsáid anseo">
<E offset="4" fromy="323" fromx="4" toy="323" tox="13" sentence="Bhí ocht tábla ar fad ar a maraídís na híobairtí." errortext="ocht tábla" msg="Urú ar iarraidh">
<E offset="28" fromy="324" fromx="28" toy="324" tox="39" sentence="Sáraíonn sé na seacht nó na hocht bliana." errortext="hocht bliana" msg="Urú ar iarraidh">
<E offset="49" fromy="325" fromx="49" toy="325" tox="62" sentence="Beidh an chéad chruinniú oifigiúil ag an gcoiste oíche Dé Luain." errortext="oíche Dé Luain" msg="Ní gá leis an fhocal «Dé»">
<E offset="23" fromy="326" fromx="23" toy="326" tox="38" sentence="Bíonn ranganna ar siúl oíche Dhéardaoin." errortext="oíche Dhéardaoin" msg="Séimhiú gan ghá">
<E offset="21" fromy="327" fromx="21" toy="327" tox="26" sentence="Bíodh bhur ngrá saor ón cur i gcéill." errortext="ón cur" msg="Urú nó séimhiú ar iarraidh">
<E offset="15" fromy="328" fromx="15" toy="328" tox="26" sentence="Ná glacaim sos ón thochailt." errortext="ón thochailt" msg="Urú nó séimhiú gan ghá">
<E offset="13" fromy="329" fromx="13" toy="329" tox="15" sentence="Amharcann sé ó a ionad cónaithe ar gach aon neach dá maireann ar talamh." errortext="ó a" msg="Ba chóir duit «óna» a úsáid anseo">
<E offset="43" fromy="330" fromx="43" toy="330" tox="46" sentence="Seo iad a gcéimeanna de réir na n-áiteanna ó ar thosaíodar." errortext="ó ar" msg="Ba chóir duit «ónar» a úsáid anseo">
<E offset="29" fromy="331" fromx="29" toy="331" tox="32" sentence="Agus rinne sé ár bhfuascailt ó ár naimhde." errortext="ó ár" msg="Ba chóir duit «ónár» a úsáid anseo">
<E offset="49" fromy="332" fromx="49" toy="332" tox="64" sentence="Seo teaghlach ag a bhfuil go leor fadhbanna agus ónar dteastaíonn tacaíocht atá dírithe." errortext="ónar dteastaíonn" msg="Ba chóir duit «óna» a úsáid anseo">
<E offset="28" fromy="333" fromx="28" toy="333" tox="36" sentence="Bhíodh súil in airde againn ónár túir faire." errortext="ónár túir" msg="Urú ar iarraidh">
<E offset="44" fromy="334" fromx="44" toy="334" tox="55" sentence="Tá do ghéaga spréite ar bhraillín ghléigeal os fharraige faoileán." errortext="os fharraige" msg="Séimhiú gan ghá">
<E offset="18" fromy="335" fromx="18" toy="335" tox="28" sentence="Ar ais leis ansin os chomhair an teilifíseáin." errortext="os chomhair" msg="Séimhiú gan ghá">
<E offset="23" fromy="336" fromx="23" toy="336" tox="26" sentence="Uaidh féin, b'fhéidir, pé é féin." errortext="pé é" msg="Réamhlitir «h» ar iarraidh">
<E offset="23" fromy="337" fromx="23" toy="337" tox="36" sentence="Agus tháinig scéin air roimh an pobal seo ar a líonmhaire." errortext="roimh an pobal" msg="Urú nó séimhiú ar iarraidh">
<E offset="18" fromy="338" fromx="18" toy="338" tox="29" sentence="Is gaiste é eagla roimh daoine." errortext="roimh daoine" msg="Séimhiú ar iarraidh">
<E offset="34" fromy="339" fromx="34" toy="339" tox="43" sentence="An bhfuil aon uachtar reoite agat sa oighear?" errortext="sa oighear" msg="Ba chóir duit «san» a úsáid anseo">
<E offset="19" fromy="340" fromx="19" toy="340" tox="30" sentence="Gortaíodh ceathrar sa n-eachtra." errortext="sa n-eachtra" msg="Ba chóir duit «san» a úsáid anseo">
<E offset="47" fromy="341" fromx="47" toy="341" tox="52" sentence="Abairt a chuireann in iúl dearóile na hÉireann sa 18ú agus sa 19ú haois." errortext="sa 18ú" msg="Ba chóir duit «san» a úsáid anseo">
<E offset="34" fromy="342" fromx="34" toy="342" tox="45" sentence="An bhfuil aon uachtar reoite agat sa cuisneoir?" errortext="sa cuisneoir" msg="Séimhiú ar iarraidh">
<E offset="32" fromy="343" fromx="32" toy="343" tox="39" sentence="Ní mór dom umhlú agus cic maith sa thóin a thabhairt duit." errortext="sa thóin" msg="Urú nó séimhiú gan ghá">
<E offset="34" fromy="344" fromx="34" toy="344" tox="43" sentence="An bhfuil aon uachtar reoite agat sa seamair?" errortext="sa seamair" msg="Réamhlitir «t» ar iarraidh">
<E offset="44" fromy="345" fromx="44" toy="345" tox="45" sentence="An bhfuil aon uachtar reoite agat sa scoil (OK)?" errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="47" fromy="346" fromx="47" toy="346" tox="48" sentence="An bhfuil aon uachtar reoite agat sa samhradh (OK)?" errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="28" fromy="347" fromx="28" toy="347" tox="41" sentence="Tá sé bráthair de chuid Ord San Phroinsias." errortext="San Phroinsias" msg="Séimhiú gan ghá">
<E offset="0" fromy="348" fromx="0" toy="348" tox="9" sentence="San fásach cuirfidh mé crainn chéadrais." errortext="San fásach" msg="Séimhiú ar iarraidh">
<E offset="34" fromy="349" fromx="34" toy="349" tox="44" sentence="An bhfuil aon uachtar reoite agat san foraois?" errortext="san foraois" msg="Séimhiú ar iarraidh">
<E offset="35" fromy="350" fromx="35" toy="350" tox="42" sentence="Tugaimid faoi abhainn na Sionainne san bhád locha ó Ros Comáin." errortext="san bhád" msg="Ba chóir duit «sa» a úsáid anseo">
<E offset="41" fromy="351" fromx="41" toy="351" tox="42" sentence="Tógadh an foirgneamh féin san 18ú haois (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="47" fromy="352" fromx="47" toy="352" tox="54" sentence="Ní féidir iad a sheinm le snáthaid ach cúig nó sé uaire." errortext="sé uaire" msg="Ba chóir duit «huaire» a úsáid anseo">
<E offset="67" fromy="353" fromx="67" toy="353" tox="68" sentence="Dúirt sé uair amháin nach raibh áit eile ar mhaith leis cónaí ann (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="17" fromy="354" fromx="17" toy="354" tox="32" sentence="Céard atá ann ná sé cathaoirleach coiste." errortext="sé cathaoirleach" msg="Séimhiú ar iarraidh">
<E offset="32" fromy="355" fromx="32" toy="355" tox="46" sentence="Cuireadh boscaí ticeála isteach seachas bhoscaí le freagraí a scríobh isteach." errortext="seachas bhoscaí" msg="Séimhiú gan ghá">
<E offset="72" fromy="356" fromx="72" toy="356" tox="73" sentence="Dá ndéanfadh sí amhlaidh réiteodh sí an fhadhb seachas bheith á ghéarú (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="25" fromy="357" fromx="25" toy="357" tox="36" sentence="Tá seacht lampa air agus seacht píopa ar gach ceann díobh." errortext="seacht píopa" msg="Urú ar iarraidh">
<E offset="26" fromy="358" fromx="26" toy="358" tox="27" sentence="Is iad na trí cheist sin (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="60" fromy="359" fromx="60" toy="359" tox="61" sentence="Lena chois sin, dá bharr seo, dá bhrí sin, ina aghaidh seo (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="18" fromy="360" fromx="18" toy="360" tox="19" sentence="Cén t-ionadh sin (OK)?" errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="0" fromy="361" fromx="0" toy="361" tox="6" sentence="Is siad na rudaí crua a mhairfidh." errortext="Is siad" msg="Ba chóir duit «iad» a úsáid anseo">
<E offset="50" fromy="362" fromx="50" toy="362" tox="61" sentence="Tá ar a laghad ceithre ní sa litir a chuir scaoll sna oifigigh." errortext="sna oifigigh" msg="Réamhlitir «h» ar iarraidh">
<E offset="31" fromy="363" fromx="31" toy="363" tox="41" sentence="Soláthraíonn an Roinn seisiúin sna Gaeilge labhartha do na mic léinn." errortext="sna Gaeilge" msg="Ba chóir duit «sa, san» a úsáid anseo">
<E offset="0" fromy="364" fromx="0" toy="364" tox="15" sentence="Sula sroicheadar an bun arís, bhí an oíche ann agus chuadar ar strae." errortext="Sula sroicheadar" msg="Ba chóir duit «sular» a úsáid anseo">
<E offset="74" fromy="365" fromx="74" toy="365" tox="75" sentence="Sula ndearna sé amhlaidh, más ea, léirigh sé a chreidiúint san fhoireann (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="30" fromy="366" fromx="30" toy="366" tox="43" sentence="Iompróidh siad thú lena lámha sula bhuailfeá do chos in aghaidh cloiche." errortext="sula bhuailfeá" msg="Urú ar iarraidh">
<E offset="4" fromy="367" fromx="4" toy="367" tox="15" sentence="Ach sular sroich sé, dúirt sí: &quot;Dúnaigí an doras air!&quot;" errortext="sular sroich" msg="Séimhiú ar iarraidh">
<E offset="45" fromy="368" fromx="45" toy="368" tox="51" sentence="Chuir iad ina suí mar a raibh onóir acu thar an cuid eile a fuair cuireadh." errortext="an cuid" msg="Séimhiú ar iarraidh">
<E offset="23" fromy="369" fromx="23" toy="369" tox="31" sentence="Bhí an chathair ag cur thar maol le filí de gach cineál." errortext="thar maol" msg="Ní úsáidtear an focal seo ach san abairtín «thar maoil» de ghnáth">
<E offset="9" fromy="370" fromx="9" toy="370" tox="17" sentence="Timpeall trí uaire a chloig ina dhiaidh sin tháinig an bhean isteach." errortext="trí uaire" msg="Ba chóir duit «huaire» a úsáid anseo">
<E offset="58" fromy="371" fromx="58" toy="371" tox="62" sentence="Scríobhaim chugaibh mar gur maitheadh daoibh bhur bpeacaí trí a ainm." errortext="trí a" msg="Ba chóir duit «trína» a úsáid anseo">
<E offset="33" fromy="372" fromx="33" toy="372" tox="37" sentence="Cuirtear i láthair na struchtúir trí a reáchtálfar gníomhartha ag an leibhéal náisiúnta." errortext="trí a" msg="Ba chóir duit «trína» a úsáid anseo">
<E offset="31" fromy="373" fromx="31" toy="373" tox="36" sentence="Ní fhillfidh siad ar an ngeata trí ar ghabh siad isteach." errortext="trí ar" msg="Ba chóir duit «trínar» a úsáid anseo">
<E offset="33" fromy="374" fromx="33" toy="374" tox="38" sentence="Beirimid an bua go caithréimeach trí an té úd a thug grá dúinn." errortext="trí an" msg="Ba chóir duit «tríd an» a úsáid anseo">
<E offset="49" fromy="375" fromx="49" toy="375" tox="54" sentence="Coinníodh lenár sála sa chaoi nárbh fhéidir siúl trí ár sráideanna." errortext="trí ár" msg="Ba chóir duit «trínár» a úsáid anseo">
<E offset="15" fromy="376" fromx="15" toy="376" tox="22" sentence="Gabhfaidh siad trí muir na hÉigipte." errortext="trí muir" msg="Séimhiú ar iarraidh">
<E offset="36" fromy="377" fromx="36" toy="377" tox="42" sentence="Feidhmeoidh an ciste coimisiúnaithe tríd na foilsitheoirí go príomha." errortext="tríd na" msg="Ba chóir duit «trí na» a úsáid anseo">
<E offset="20" fromy="378" fromx="20" toy="378" tox="30" sentence="Ba é an gleann cúng trína ghabh an abhainn." errortext="trína ghabh" msg="Urú ar iarraidh">
<E offset="28" fromy="379" fromx="28" toy="379" tox="42" sentence="Is mar a chéile an próiseas trínar ndéantar é seo." errortext="trínar ndéantar" msg="Ba chóir duit «trína» a úsáid anseo">
<E offset="4" fromy="380" fromx="4" toy="380" tox="16" sentence="Mar trínár peacaí, tá do phobal ina ábhar gáire ag cách máguaird orainn." errortext="trínár peacaí" msg="Urú ar iarraidh">
<E offset="19" fromy="381" fromx="19" toy="381" tox="33" sentence="Nár thug sí póg do gach uile duine?" errortext="gach uile duine" msg="Séimhiú ar iarraidh">
<E offset="26" fromy="382" fromx="26" toy="382" tox="27" sentence="D'ith na daoine uile bia (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="17" fromy="383" fromx="17" toy="383" tox="28" sentence="Idir dhá sholas, um tráthnóna, faoi choim na hoíche agus sa dorchadas." errortext="um tráthnóna" msg="Séimhiú ar iarraidh">
<E offset="51" fromy="384" fromx="51" toy="384" tox="52" sentence="Straitéis Chomhphobail um bainistíocht dramhaíola (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="22" fromy="385" fromx="22" toy="385" tox="29" sentence="Bhíodh an dinnéar acu um mheán lae." errortext="um mheán" msg="Séimhiú gan ghá">
<E offset="10" fromy="386" fromx="10" toy="386" tox="15" sentence="An lá dar gcionn nochtadh gealltanas an Taoisigh sa nuachtán." errortext="gcionn" msg="Ní úsáidtear an tabharthach ach in abairtí speisialta">
<E offset="15" fromy="387" fromx="15" toy="387" tox="20" sentence="Conas a bheadh Éirinn agus Meiriceá difriúil?" errortext="Éirinn" msg="Ní úsáidtear an tabharthach ach in abairtí speisialta">
<E offset="17" fromy="388" fromx="17" toy="388" tox="18" sentence="Ba chois tine é (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="44" fromy="389" fromx="44" toy="389" tox="45" sentence="Bhí cuid mhór teannais agus iomaíochta ann (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="22" fromy="390" fromx="22" toy="390" tox="23" sentence="Galar crúibe is béil (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="30" fromy="391" fromx="30" toy="391" tox="31" sentence="Caitheann sé go leor ama ann (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="22" fromy="392" fromx="22" toy="392" tox="33" sentence="An raibh mórán daoine ag an tsiopa?" errortext="ag an tsiopa" msg="Ní gá leis an leagan ginideach anseo">
<E offset="31" fromy="393" fromx="31" toy="393" tox="46" sentence="Ní raibh dúil bheo le feiceáil ar na bhfuinneog." errortext="ar na bhfuinneog" msg="Ní gá leis an leagan ginideach anseo">
<E offset="42" fromy="394" fromx="42" toy="394" tox="43" sentence="Bhí, dála an scéil, ocht mbean déag aige (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="3" fromy="395" fromx="3" toy="395" tox="19" sentence="Cá bhfuil an tseomra?" errortext="bhfuil an tseomra" msg="Ní gá leis an leagan ginideach anseo">
<E offset="3" fromy="396" fromx="3" toy="396" tox="16" sentence="Is iad na nGardaí." errortext="iad na nGardaí" msg="Ní gá leis an leagan ginideach anseo">
<E offset="21" fromy="397" fromx="21" toy="397" tox="22" sentence="Éirí Amach na Cásca (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="40" fromy="398" fromx="40" toy="398" tox="41" sentence="Leas phobal na hÉireann agus na hEorpa (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="42" fromy="399" fromx="42" toy="399" tox="43" sentence="Fáilte an deamhain is an diabhail romhat (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="36" fromy="400" fromx="36" toy="400" tox="37" sentence="Go deo na ndeor, go deo na díleann (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="9" fromy="401" fromx="9" toy="401" tox="18" sentence="Clann na bPoblachta a thug siad orthu féin." errortext="bPoblachta" msg="Urú gan ghá">
<E offset="36" fromy="402" fromx="36" toy="402" tox="48" sentence="Cruthaíodh an chloch sin go domhain faoin dtalamh." errortext="faoin dtalamh" msg="Urú nó séimhiú gan ghá">
<E offset="11" fromy="403" fromx="11" toy="403" tox="19" sentence="Tá ainm in n-easnamh a mbeadh coinne agat leis." errortext="n-easnamh" msg="Urú gan ghá">
<E offset="24" fromy="404" fromx="24" toy="404" tox="28" sentence="Tá muid compordach inar gcuid &quot;fírinní&quot; féin." errortext="gcuid" msg="Urú gan ghá">
<E offset="63" fromy="405" fromx="63" toy="405" tox="66" sentence="Tá siad ag éileamh go n-íocfaí iad as a gcuid costais agus iad mbun traenála." errortext="mbun" msg="Urú gan ghá">
<E offset="50" fromy="406" fromx="50" toy="406" tox="51" sentence="Cruthaíodh an chloch sin go domhain faoin gcrann (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="5" fromy="407" fromx="5" toy="407" tox="8" sentence="Nach holc an mhaise duit a bheith ag magadh." errortext="holc" msg="Réamhlitir «h» gan ghá">
<E offset="41" fromy="408" fromx="41" toy="408" tox="42" sentence="Dún do bhéal, a mhiúil na haon chloiche (OK)!" errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="76" fromy="409" fromx="76" toy="409" tox="77" sentence="Scaoileadh seachtar duine chun báis i mBaile Átha Cliath le hocht mí anuas (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="63" fromy="410" fromx="63" toy="410" tox="64" sentence="Ní dhúnfaidh an t-ollmhargadh go dtí a haon a chlog ar maidin (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="68" fromy="411" fromx="68" toy="411" tox="69" sentence="Is mar gheall ar sin atá líníocht phictiúrtha chomh húsáideach sin (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="35" fromy="412" fromx="35" toy="412" tox="36" sentence="Tá sí ag feidhmiú go héifeachtach (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="55" fromy="413" fromx="55" toy="413" tox="56" sentence="Ní hionann cuingir na ngabhar agus cuingir na lánúine (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="3" fromy="414" fromx="3" toy="414" tox="6" sentence="Ba hiad na hamhráin i dtosach ba chúis leis." errortext="hiad" msg="Réamhlitir «h» gan ghá">
<E offset="33" fromy="415" fromx="33" toy="415" tox="34" sentence="Ní hé lá na gaoithe lá na scolb (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="14" fromy="416" fromx="14" toy="416" tox="17" sentence="Ba iad na trí háit iad Bostún, Baile Átha Cliath agus Nua Eabhrac." errortext="háit" msg="Réamhlitir «h» gan ghá">
<E offset="28" fromy="417" fromx="28" toy="417" tox="29" sentence="Phós sé bean eile ina háit (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="45" fromy="418" fromx="45" toy="418" tox="46" sentence="Cá ham a tháinig sí a staidéar anseo ó thús (OK)?" errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="71" fromy="419" fromx="71" toy="419" tox="72" sentence="Bhí a dheartháir ag siúl na gceithre hairde agus bhí seisean ina shuí (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="37" fromy="420" fromx="37" toy="420" tox="38" sentence="Chaith sé an dara hoíche i Sligeach (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="54" fromy="421" fromx="54" toy="421" tox="55" sentence="Tá sé i gcóip a rinneadh i lár na cúigiú haoise déag (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="37" fromy="422" fromx="37" toy="422" tox="38" sentence="Chuir sí a dhá huillinn ar an bhord (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="16" fromy="423" fromx="16" toy="423" tox="23" sentence="Chuir mé mo dhá huillinn ar an bhord." errortext="huillinn" msg="Réamhlitir «h» gan ghá">
<E offset="37" fromy="424" fromx="37" toy="424" tox="38" sentence="Cuireadh cuid mhaith acu go hÉirinn (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="73" fromy="425" fromx="73" toy="425" tox="74" sentence="Tá tús curtha le clár chun rampaí luchtaithe a chur sna hotharcharranna (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="37" fromy="426" fromx="37" toy="426" tox="38" sentence="Cuimhnígí ar na héachtaí a rinne sé (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="92" fromy="427" fromx="92" toy="427" tox="93" sentence="Creidim go mbeidh iontas ar mhuintir na hÉireann nuair a fheiceann siad an feidhmchlár seo (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="48" fromy="428" fromx="48" toy="428" tox="49" sentence="Tháinig múinteoir úr i gceithre huaire fichead (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="26" fromy="429" fromx="26" toy="429" tox="31" sentence="Caithfidh siad turas cúig huaire a chloig a dhéanamh." errortext="huaire" msg="Réamhlitir «h» gan ghá">
<E offset="10" fromy="430" fromx="10" toy="430" tox="19" sentence="In Éirinn chaitheann breis is 30 faoin gcéad de mhná toitíní." errortext="chaitheann" msg="Séimhiú gan ghá">
<E offset="0" fromy="431" fromx="0" toy="431" tox="8" sentence="Chuirfear in iúl do dhaoine gurb é sin an aidhm atá againn." errortext="Chuirfear" msg="Séimhiú gan ghá">
<E offset="73" fromy="432" fromx="73" toy="432" tox="74" sentence="Déan cur síos ar dhá thoradh a bhíonn ag caitheamh tobac ar an tsláinte (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="67" fromy="433" fromx="67" toy="433" tox="68" sentence="Má bhrúitear idir chnónna agus bhlaoscanna faightear ola inchaite (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="39" fromy="434" fromx="39" toy="434" tox="40" sentence="Ní chothaíonn na briathra na bráithre (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="58" fromy="435" fromx="58" toy="435" tox="59" sentence="Cha bhíonn striapachas agus seafóid Mheiriceá ann feasta (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="66" fromy="436" fromx="66" toy="436" tox="67" sentence="Tá cleachtadh ag daoine ó bhíonn siad an-óg ar uaigneas imeachta (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="64" fromy="437" fromx="64" toy="437" tox="65" sentence="Ar an láithreán seo gheofar foclóirí agus liostaí téarmaíochta (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="14" fromy="438" fromx="14" toy="438" tox="26" sentence="An oíche sin, sular chuaigh sé a chodladh, chuir sé litir fhada dom." errortext="sular chuaigh" msg="Tá gá leis an fhoirm spleách anseo">
<E offset="13" fromy="439" fromx="13" toy="439" tox="25" sentence="Tá mioneolas faoinar rinne sé ansin." errortext="faoinar rinne" msg="Tá gá leis an fhoirm spleách anseo">
<E offset="0" fromy="440" fromx="0" toy="440" tox="12" sentence="Níor rinneadh a leithéid le fada agus ní raibh aon slat tomhais acu." errortext="Níor rinneadh" msg="Tá gá leis an fhoirm spleách anseo">
<E offset="35" fromy="441" fromx="35" toy="441" tox="49" sentence="Teastaíonn uaidh an scéal a insint sula ngeobhaidh sé bás." errortext="sula ngeobhaidh" msg="Tá gá leis an fhoirm spleách anseo">
<E offset="26" fromy="442" fromx="26" toy="442" tox="31" sentence="Tá folúntas sa chomhlacht ina tá mé ag obair faoi láthair." errortext="ina tá" msg="Urú ar iarraidh">
<E offset="0" fromy="443" fromx="0" toy="443" tox="12" sentence="Ní gheobhaidh an mealltóir nathrach aon táille." errortext="Ní gheobhaidh" msg="Tá gá leis an fhoirm spleách anseo">
<E offset="3" fromy="444" fromx="3" toy="444" tox="9" sentence="Má dhearna sí praiseach de, thosaigh sí arís go bhfuair sí ceart é." errortext="dhearna" msg="Ní gá leis an fhoirm spleách">
<E offset="58" fromy="445" fromx="58" toy="445" tox="59" sentence="Chan fhacthas dom go raibh an saibhreas céanna i mBéarla (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="32" fromy="446" fromx="32" toy="446" tox="37" sentence="Chuaigh sé chun na huaimhe agus fhéach sé isteach." errortext="fhéach" msg="Réamhlitir «d'» ar iarraidh">
<E offset="31" fromy="447" fromx="31" toy="447" tox="32" sentence="Fágadh faoi smacht a lámh iad (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="19" fromy="448" fromx="19" toy="448" tox="20" sentence="An íosfá ubh eile (OK)?" errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="19" fromy="449" fromx="19" toy="449" tox="33" sentence="Níorbh fhada, ámh, gur d'fhoghlaim sí an téarma ceart uathu." errortext="gur d'fhoghlaim" msg="Réamhlitir «d'» gan ghá">
<E offset="48" fromy="450" fromx="48" toy="450" tox="49" sentence="Nílim ag rá gur d'aon ghuth a ainmníodh Sheehy (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="9" fromy="451" fromx="9" toy="451" tox="17" sentence="Ritheann an Sláine tríd an pháirc." errortext="an Sláine" msg="Cor cainte aisteach">
<E offset="61" fromy="452" fromx="61" toy="452" tox="62" sentence="Nochtadh na fírinne sa dóigh a n-admhódh an té is bréagaí í (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="47" fromy="453" fromx="47" toy="453" tox="56" sentence="Tá a chumas sa Ghaeilge níos airde ná cumas na bhfear óga." errortext="bhfear óga" msg="Tá gá leis an leagan uatha anseo">
<E offset="37" fromy="454" fromx="37" toy="454" tox="38" sentence="Beirt bhan Mheiriceánacha a bhí ann (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="38" fromy="455" fromx="38" toy="455" tox="39" sentence="Tá sé-- tá sé- mo ---shin-seanathair (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha «^OK» neamhdhóchúil)">
<E offset="3" fromy="456" fromx="3" toy="456" tox="8" sentence="Is foláir dóibh a ndualgais a chomhlíonadh." errortext="foláir" msg="Ní úsáidtear an focal seo ach san abairtín «ní foláir» de ghnáth">
<E offset="23" fromy="457" fromx="23" toy="457" tox="24" sentence="Bhain na toibreacha le re eile agus le dream daoine atá imithe." errortext="re" msg="Ní úsáidtear an focal seo ach san abairtín «gach re» de ghnáth">
<E offset="14" fromy="458" fromx="14" toy="458" tox="17" sentence="Labhair mé ar shon na daoine." errortext="shon" msg="Ní úsáidtear an focal seo ach san abairtín «ar son» de ghnáth">
<E offset="37" fromy="459" fromx="37" toy="459" tox="39" sentence="Tá sé tábhachtach bheith ag obair an son na cearta." errortext="son" msg="Ní úsáidtear an focal seo ach san abairtín «ar son» de ghnáth">
RESEOF

$results = decode('utf8', $results);

my @resultarr = split(/\n/,$results);

my $output = $gr->grammatical_errors($test);
my $errorno = 0;
is( @resultarr, @$output, 'Verifying correct number of errors found');
foreach my $error (@$output) {
	$error =~ m/fromy="([1-9][0-9]*)".*errortext="([^"]+)"/;
	is ( $error, $resultarr[$errorno], "Verifying error \"$2\" found on input line $1" );
	++$errorno;
}

exit;
