#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More tests => 201;
use Lingua::GA::Gramadoir::Languages;
use Lingua::GA::Gramadoir qw( xml_stream grammatical_errors spell_check );
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
Tabhair go leor leor de na na ruda� seo do do chara, a Chaoimh�n.
Chuaigh s� in olcas ina dhiaidh sin agus bh� an-imn� orthu.
Tharla s� seo ar l� an-m�fheili�nach, an D�ardaoin.
N� maith liom na daoine m�intleacht�la.
Tr� chomhtharl�int, bh� siad sa tuaisceart ag an am.
S�lim n�rbh ea, agus is docha nach bhfuil i gceist ach easpa smaoinimh.
T� s�il le feabhas nuair a thos�idh airgead ag teacht isteach � ola agus g�s i mBearna Timor.
Beidh nuacht�in shuaracha i ngreim c� nach mbeadh cinsireacht den droch-chin�al i gceist.
Bh� s� p�irteach sa ch�ad l�iri� poibl� de Riverdance.
Beidh an tionchar le moth� n�os m� i gc�s comhlachta� �ireannacha mar gur mionairgeadra � an punt.
Bh� an dream d�-armtha ag iarraidh a gcuid gunna�.
An bhfuil ayn uachtar roeite agattt?
B�onn an ge�l ag satailt ar an dubh.
Ach bh� m� ag lean�int ar aghaidh an t-am ar fad leis.
Nach holc an mhaise duit a bheith ag magadh.
Ba hiad na hamhr�in i dtosach ba ch�is leis.
Ba iad na tr� h�it iad Bost�n, Baile �tha Cliath agus Nua Eabhrac.
Sa dara alt, d�an cur s�os ar a bhfaca siad sa Sp�inn.
Oirfeadh s�ol �iti�il n�os fearr n� an s�ol a h�s�idtear go minic.
T� ceacht stairi�il uath�il do chuairteoir� san t-ionad seo.
In �irinn chaitheann breis is 30 faoin gc�ad de mhn� toit�n�.
T� s� riachtanach ar mhaithe le feidhmi� an phlean a bheidh ceaptha ag an eagra�ocht ceannasach.
T� na lachain slachtmhara ar eitilt.
T� an Rialtas tar �is �it na Gaeilge i saol na t�re a ceisti�.
Bh�odar ag r� ar an aonach gur agamsa a bh� na huain ab fearr.
N� bheidh ach mhallacht i nd�n d� � na cin�ocha agus fuath � na n�isi�in.
An bhfuil aon uachtar reoite ar an cuntar?
M� shu�onn t� ag bhord le flaith, tabhair faoi deara go c�ramach c�ard at� leagtha romhat.
Bl�tha�onn s� amhail bhl�th an mhachaire.
An bainim sult as b�s an drochdhuine?
N� f�idir an Gaeltacht a choinne�il mar r�igi�n Gaeilge go n�isi�nta gan athr� bun�sach.
Cad � an chomhairle a thug an ochtapas d�?
Ch�irigh s� na lampa� le solas a chaitheamh os comhair an coinnleora.
Comhl�n�idh saor�nacht an Aontais an saor�nacht n�isi�nta agus n� ghabhfaidh s� a hionad.
B�onn na cim� ar a suaimhneas le ch�ile gan guth an s�il�ara le clos a thuilleadh.
T� sin r�ite cheana f�in acu le muintir an t�re seo.
Is � is d�ich� go raibh baint ag an eisimirce leis an laghd� i l�on an gcainteoir� Gaeilge.
Ba � an fear an phortaigh a th�inig thart leis na pl�ta� bia.
T� dh� shiombail ag an bharr gach leathanaigh.
N� bheidh aon bunt�iste againn orthu sin.
Ar gcaith t� do chiall agus do ch�adfa� ar fad?
N� amh�in �r dh� chosa, ach nigh �r l�mha!
Gheobhaimid maoin de gach s�rt, agus l�onfaimid �r tithe le creach.
N�l aon n� arbh fi� a shant� seachas �.
Ba maith liom fios a thabhairt anois daoibh.
Ba eol duit go hioml�n m'anam.
D'fhan beirt buachaill sa champa.
D'fhan beirt bhuachaill cancrach sa champa.
N� amh�in bhur dh� chosa, ach nigh bhur l�mha!
D�anaig� beart leis de r�ir bhur briathra.
C� cuireann t� do thr�ad ar f�arach?
C� �it a nochtfadh s� � f�in ach i mBost�n!
C� ch�s d�inn bheith ag m�inne�il thart anseo?
C�r f�g t� eisean?
C�r bhf�g t� eisean?
C�r f�gadh eisean (OK)?
C� iad na fir seo ag fanacht farat?
C� an ceart at� agamsa a thuilleadh f�s a lorg ar an r�?
D'fhoilsigh s� a c�ad cnuasach fil�ochta i 1995.
Chuir siad fios orm ceithre uaire ar an tsl� sin.
Beidh ar Bhord Feidhmi�ch�in an tUachtar�n agus ceithre ball eile.
C�n amhr�na� is fearr leat?
Bh� an ch�ad cruinni� den Choimisi�n i Ros Muc i nGaeltacht na Gaillimhe.
T� s� chomh iontach le sneachta dearg.
Chuir m� c�ad punta chuig an banaltra.
N�l t� do do sheoladh chuig dhaoine a labhra�onn teanga dhothuigthe.
Bh� s� c�ig bhanl�mh ar fhad, c�ig banl�mh ar leithead.
Beirim mo mhionna dar an beart a rinne Dia le mo shinsir.
Dearbha�m � dar chuthach m'�ada i gcoinne na gcin�ocha eile.
Sa dara bliain d�ag d�r braighdeanas, th�inig fear ar a theitheadh.
D'oibrigh m� liom go dt� D� Aoine.
Bh� deich tobar f�oruisce agus seacht� crann pailme ann.
T�gfaidh m� do coinnleoir �na ionad, mura nd�ana t� aithr�.
Is c�is imn� don pobal a laghad maoinithe a dh�antar ar Na�scoileanna.
Creidim go raibh siad de an thuairim ch�anna.
T� dh� teanga oifigi�la le st�das bunreacht�il � labhairt sa t�r seo.
C� bhfuil feoil le f�il agamsa le tabhairt do an mhuintir seo?
Is amhlaidh a bheidh freisin do na tagairt� do airteagail.
T� s� de ch�ram seirbh�s a chur ar f�il do a gcustaim�ir� i nGaeilge.
Seinnig� moladh ar an gcruit do �r nDia.
Tabharfaidh an tUachtar�n a �r�id ag leath i ndiaidh a d� d�ag D� Sathairn.
T� an domhan go l�ir faoi suaimhneas.
Caithfidh pobal na Gaeltachta iad f�in cinneadh a dh�anamh faoi an Ghaeilge.
Cuireann s� a neart mar chrios faoi a coim.
Cuireann s� cin�ocha faoi �r smacht agus cuireann s� n�isi�in faoin�r gcosa.
T� dualgas ar an gComhairle sin tabhairt faoin c�ram seo.
N� bheidh gear�n ag duine ar bith faoin gciste fial at� faoin�r c�ram.
Beidh par�id L� Fh�ile Ph�draig i mBost�n.
T� F�ile Bhealtaine an Oireachtais ar si�l an tseachtain seo (OK).
T� ar chumas an duine saol ioml�n a chaitheamh gan theanga eile � br� air.
T� gruaim mh�r orm gan Chaitl�n.
Is st�it ilteangacha iad cuid mh�r de na st�it sin at� aonteangach go oifigi�il.
N� bheidh bonn compar�ide ann go beidh tortha� Dhaon�ireamh 2007 ar f�il.
Rug s� ar ais m� go dhoras an Teampaill.
Chuaigh m� suas go an doras c�il a chaisle�in.
Tar, t�anam go dt� bhean na bhf�seanna.
Ba mhaith liom gur bhf�gann daoine �ga an scoil agus iad ullmhaithe.
Bhraith m� gur fuair m� boladh trom tais uathu.
An ea nach c�s leat gur bhf�g mo dheirfi�r an freastal f�msa i m'aonar?
B'fh�idir gurbh fearr � seo duit n� leamhnacht na b� ba mhilse i gcontae Chill Mhant�in.
An bhfuil aon uachtar reoite agat i cuisneoir?
An bhfuil aon uachtar reoite agat i chuisneoir?
An bhfuil aon uachtar reoite agaibh i bhur gcuisneoir?
An bhfuil aon uachtar reoite agat i dh� chuisneoir?
An bhfuil aon uachtar reoite agat i an chuisneoir?
An bhfuil aon uachtar reoite agat i na cuisneoir�?
An bhfuil aon uachtar reoite i a cuisneoir?
Rinne gach cine � sin sna cathracha i ar lonna�odar.
An bhfuil aon uachtar reoite i �r gcuisneoir?
Thug s� seo deis dom breathn� in mo thimpeall.
T� beirfean in�r craiceann faoi mar a bheimis i sorn.
Is tuar d�chais � an m�id dul chun cinn at� d�anta le bhlianta beaga.
D'fh�adfadh t�bhacht a bheith ag baint le an gc�ad toisc d�obh sin.
Molann an Coimisi�n go maoineofa� sc�im chun tac� le na pobail sin.
Labhra�odh gach duine an fh�rinne le a chomharsa.
Beir i do l�imh ar an tslat le ar bhuail t� an abhainn, agus seo leat.
Ba mhaith liom bu�ochas a ghlacadh le �r bhfoireann riarach�in.
T�gann siad cuid de le iad f�in a th�amh.
T� do scrios chomh leathan leis an farraige.
Is linne � ar nd�igh agus len�r clann.
M� tugann r� breith ar na boicht le cothromas, bun�far a r�chathaoir go br�ch.
Roghna�tear an bhliain 1961 mar pointe tosaigh don anail�s.
Comhl�on mo aitheanta agus mairfidh t� beo.
Ceapadh mise i mo bolscaire.
T� m� ag scl�bha�ocht ag iarraidh mo dh� gas�r a chur tr� scoil. 
Mura tagann aon duine i gcabhair orainn, rachaimid anonn chugaibh.
Murar chrutha�tear l� agus o�che... teilgim uaim sliocht Iac�ib.
Murar gcruthaigh mise l� agus o�che... teilgim uaim sliocht Iac�ib.
An bhfuil aon uachtar reoite ag fear na b�d?
Is m�r ag n�isi�n na �ireann a choibhneas speisialta le daoine de bhunadh na h�ireann at� ina gc�na� ar an gcoigr�och.
Chuir an Coimisi�n f�in comhfhreagras chuig na eagra�ochta� seo ag lorg eolais faoina ngn�omha�ochta�.
N� iompa�g� chun na n-�ol, agus n� dealbha�g� d�ithe de mhiotal.
Is fearr de bh�ile luibheanna agus gr� leo n� mhart m�ith agus gr�in leis.
Nach bainfidh m� uaidh an m�id a ghoid s� uaim?
Rinneadh an roinnt don naoi treibh go leith ar cranna.
Th�inig na br�ga chomh fada siar le haimsir Naomh Ph�draig f�in.
N�r bre� liom cla�omh a bheith agam i mo ghlac!
N�r bhfreagair s� th�, focal ar fhocal.
Feicimid gur de dheasca a n-easumhla�ochta n�rbh f�idir leo dul isteach ann.
N� f�adfaidh a gcuid airgid n� �ir iad a sh�bh�il.
N� iad sin do ph�opa� ar an t�bla!
Bh� an m�id sin airgid n�ba luachmhar d�inn n� maoin an domhain.
Eisean beag�n n�b �ga n� mise.
Eisean beag�n n�ba �ige n� mise.
Bh� na p�ist� ag �ir� n�ba tr�ine.
"T�," ar sise, "ach n�or fhacthas � sin."
N�or g� do dheora� riamh codladh sa tsr�id; Bh� mo dhoras riamh ar leathadh.
"T�," ar sise, "ach n�or fuair muid aon ocras f�s.
N�or mbain s� leis an dream a bh� i gcogar ceilge.
N�orbh fol�ir d� �isteacht a thabhairt dom.
Ach anois � cuimhn�m air, bh� ard�n coincr�ite sa ph�irc.
Tabhair an t-ord� seo leanas � b�al.
B�odh bhur ngr� saor � an gcur i gc�ill.
Bh� ocht t�bla ar fad ar a mara�d�s na h�obairt�.
B�odh bhur ngr� saor �n cur i gc�ill.
Amharcann s� � a ionad c�naithe ar gach aon neach d� maireann ar talamh.
Seo iad a gc�imeanna de r�ir na n-�iteanna � ar thosa�odar.
Agus rinne s� �r bhfuascailt � �r naimhde.
Bh�odh s�il in airde againn �n�r t�ir faire.
T� do gh�aga spr�ite ar bhraill�n ghl�igeal os fharraige faoile�n.
Uaidh f�in, b'fh�idir, p� � f�in.
Agus th�inig sc�in air roimh an pobal seo ar a l�onmhaire.
Is gaiste � eagla roimh daoine.
An bhfuil aon uachtar reoite agat sa cuisneoir?
An bhfuil aon uachtar reoite agat sa seamair?
An bhfuil aon uachtar reoite agat sa scoil (OK)?
An bhfuil aon uachtar reoite agat sa samhradh (OK)?
T� s� br�thair de chuid Ord San Phroinsias.
San f�sach cuirfidh m� crainn ch�adrais.
An bhfuil aon uachtar reoite agat san foraois?
An bhfuil aon uachtar reoite agat sa oighear?
Tugaimid faoi abhainn na Sionainne san bh�d locha � Ros Com�in.
N� f�idir iad a sheinm le sn�thaid ach c�ig n� s� uaire.
D�irt s� uair amh�in nach raibh �it eile ar mhaith leis c�na� ann (OK).
C�ard at� ann n� s� cathaoirleach coiste.
Cuireadh bosca� tice�la isteach seachas bhosca� le freagra� a scr�obh isteach.
T� seacht lampa air agus seacht p�opa ar gach ceann d�obh.
T� ar a laghad ceithre n� sa litir a chuir scaoll sna oifigigh.
Iompr�idh siad th� lena l�mha sula bhuailfe� do chos in aghaidh cloiche.
Ach sular sroich s�, d�irt s�: "D�naig� an doras air!"
Chuir iad ina su� mar a raibh on�ir acu thar an cuid eile a fuair cuireadh.
Timpeall tr� uaire a chloig ina dhiaidh sin th�inig an bhean isteach.
Scr�obhaim chugaibh mar gur maitheadh daoibh bhur bpeaca� tr� a ainm.
N� fhillfidh siad ar an ngeata tr� ar ghabh siad isteach.
Beirimid an bua go caithr�imeach tr� an t� �d a thug gr� d�inn.
Coinn�odh len�r s�la sa chaoi n�rbh fh�idir si�l tr� �r sr�ideanna.
Gabhfaidh siad tr� muir na h�igipte.
Feidhmeoidh an ciste coimisi�naithe tr�d na foilsitheoir� go pr�omha.
Mar tr�n�r peaca�, t� do phobal ina �bhar g�ire ag c�ch m�guaird orainn.
Idir dh� sholas, um tr�thn�na, faoi choim na ho�che agus sa dorchadas.
T� s�-- t� s�- mo ---shin-seanathair (OK).
Maidin l� ar na mh�rach thug a fhear gaoil cuairt air.
Bhain na toibreacha le re eile agus le dream daoine at� imithe.
EOF

my $results = <<'RESEOF';
<E offset="43" fromy="1" fromx="43" toy="1" tox="49" sentence="Ní raibh líon mór daoine bainteach leis an scaifte a bhí ag iarraidh mioscais a chothú." errortext="scaifte" msg="Foirm neamhchaighdeánach de /scata/">
<E offset="4" fromy="2" fromx="4" toy="2" tox="15" sentence="Ach thosnaíos-sa ag léamh agus bhog mé isteach ionam féin." errortext="thosnaíos-sa" msg="Foirm neamhchaighdeánach de /thosnaigh (thosaigh)/">
<E offset="24" fromy="3" fromx="24" toy="3" tox="28" sentence="Tabhair go leor leor de na na rudaí seo do do chara, a Chaoimhín." errortext="na na" msg="Focal céanna faoi dhó">
<E offset="45" fromy="4" fromx="45" toy="4" tox="51" sentence="Chuaigh sí in olcas ina dhiaidh sin agus bhí an-imní orthu." errortext="an-imní" msg="Focal anaithnid ach bunaithe ar /imní/ is dócha">
<E offset="20" fromy="5" fromx="20" toy="5" tox="35" sentence="Tharla sé seo ar lá an-mífheiliúnach, an Déardaoin." errortext="an-mífheiliúnach" msg="Bunaithe go mícheart ar an bhfréamh /mífheiliúnach/">
<E offset="24" fromy="6" fromx="24" toy="6" tox="37" sentence="Ní maith liom na daoine míintleachtúla." errortext="míintleachtúla" msg="Bunaithe go mícheart ar an bhfréamh /intleachtúla (intleachtacha, intleachtaí)/">
<E offset="4" fromy="7" fromx="4" toy="7" tox="17" sentence="Trí chomhtharlúint, bhí siad sa tuaisceart ag an am." errortext="chomhtharlúint" msg="Bunaithe ar foirm neamhchaighdeánach de /tharlú/">
<E offset="24" fromy="8" fromx="24" toy="8" tox="28" sentence="Sílim nárbh ea, agus is docha nach bhfuil i gceist ach easpa smaoinimh." errortext="docha" msg="An raibh /dócha/ ar intinn agat?">
<E offset="87" fromy="9" fromx="87" toy="9" tox="91" sentence="Tá súil le feabhas nuair a thosóidh airgead ag teacht isteach ó ola agus gás i mBearna Timor." errortext="Timor" msg="An raibh /Tíomór/ ar intinn agat?">
<E offset="66" fromy="10" fromx="66" toy="10" tox="78" sentence="Beidh nuachtáin shuaracha i ngreim cé nach mbeadh cinsireacht den droch-chinéal i gceist." errortext="droch-chinéal" msg="Bunaithe ar focal mílitrithe go coitianta /chinéal (chineál)/?">
<E offset="43" fromy="11" fromx="43" toy="11" tox="52" sentence="Bhí sé páirteach sa chéad léiriú poiblí de Riverdance." errortext="Riverdance" msg="Is féidir gur focal iasachta é seo (tá na litreacha /Riv/ neamhdhóchúil)">
<E offset="74" fromy="12" fromx="74" toy="12" tox="86" sentence="Beidh an tionchar le mothú níos mó i gcás comhlachtaí Éireannacha mar gur mionairgeadra é an punt." errortext="mionairgeadra" msg="Focal anaithnid ach is féidir gur comhfhocal /mion+airgeadra/ é?">
<E offset="13" fromy="13" fromx="13" toy="13" tox="21" sentence="Bhí an dream dí-armtha ag iarraidh a gcuid gunnaí." errortext="dí-armtha" msg="Focal anaithnid ach is féidir gur comhfhocal neamhchaighdeánach /dí+armtha/ é?">
<E offset="10" fromy="14" fromx="10" toy="14" tox="12" sentence="An bhfuil ayn uachtar roeite agattt?" errortext="ayn" msg="Focal anaithnid /aon, ann, an/?">
<E offset="22" fromy="14" fromx="22" toy="14" tox="27" sentence="An bhfuil ayn uachtar roeite agattt?" errortext="roeite" msg="Focal anaithnid /reoite/?">
<E offset="29" fromy="14" fromx="29" toy="14" tox="34" sentence="An bhfuil ayn uachtar roeite agattt?" errortext="agattt" msg="Is féidir gur focal iasachta é seo (tá na litreacha /ttt/ neamhdhóchúil)">
<E offset="9" fromy="15" fromx="9" toy="15" tox="12" sentence="Bíonn an geál ag satailt ar an dubh." errortext="geál" msg="Focal ceart ach an-neamhchoitianta">
<E offset="23" fromy="16" fromx="23" toy="16" tox="40" sentence="Ach bhí mé ag leanúint ar aghaidh an t-am ar fad leis." errortext="ar aghaidh an t-am" msg="Tá gá leis an leagan ginideach anseo">
<E offset="0" fromy="17" fromx="0" toy="17" tox="8" sentence="Nach holc an mhaise duit a bheith ag magadh." errortext="Nach holc" msg="Réamhlitir /h/ gan ghá">
<E offset="0" fromy="18" fromx="0" toy="18" tox="6" sentence="Ba hiad na hamhráin i dtosach ba chúis leis." errortext="Ba hiad" msg="Réamhlitir /h/ gan ghá">
<E offset="10" fromy="19" fromx="10" toy="19" tox="17" sentence="Ba iad na trí háit iad Bostún, Baile Átha Cliath agus Nua Eabhrac." errortext="trí háit" msg="Réamhlitir /h/ gan ghá">
<E offset="3" fromy="20" fromx="3" toy="20" tox="10" sentence="Sa dara alt, déan cur síos ar a bhfaca siad sa Spáinn." errortext="dara alt" msg="Réamhlitir /h/ ar iarraidh">
<E offset="44" fromy="21" fromx="44" toy="21" tox="55" sentence="Oirfeadh síol áitiúil níos fearr ná an síol a húsáidtear go minic." errortext="a húsáidtear" msg="Réamhlitir /h/ gan ghá">
<E offset="44" fromy="22" fromx="44" toy="22" tox="54" sentence="Tá ceacht stairiúil uathúil do chuairteoirí san t-ionad seo." errortext="san t-ionad" msg="Réamhlitir /t/ gan ghá">
<E offset="3" fromy="23" fromx="3" toy="23" tox="19" sentence="In Éirinn chaitheann breis is 30 faoin gcéad de mhná toitíní." errortext="Éirinn chaitheann" msg="Séimhiú gan ghá">
<E offset="74" fromy="24" fromx="74" toy="24" tox="94" sentence="Tá sé riachtanach ar mhaithe le feidhmiú an phlean a bheidh ceaptha ag an eagraíocht ceannasach." errortext="eagraíocht ceannasach" msg="Séimhiú ar iarraidh">
<E offset="6" fromy="25" fromx="6" toy="25" tox="24" sentence="Tá na lachain slachtmhara ar eitilt." errortext="lachain slachtmhara" msg="Séimhiú ar iarraidh">
<E offset="52" fromy="26" fromx="52" toy="26" tox="60" sentence="Tá an Rialtas tar éis áit na Gaeilge i saol na tíre a ceistiú." errortext="a ceistiú" msg="Séimhiú ar iarraidh">
<E offset="53" fromy="27" fromx="53" toy="27" tox="60" sentence="Bhíodar ag rá ar an aonach gur agamsa a bhí na huain ab fearr." errortext="ab fearr" msg="Séimhiú ar iarraidh">
<E offset="10" fromy="28" fromx="10" toy="28" tox="22" sentence="Ní bheidh ach mhallacht i ndán dó ó na ciníocha agus fuath ó na náisiúin." errortext="ach mhallacht" msg="Séimhiú gan ghá">
<E offset="29" fromy="29" fromx="29" toy="29" tox="40" sentence="An bhfuil aon uachtar reoite ar an cuntar?" errortext="ar an cuntar" msg="Urú nó séimhiú ar iarraidh">
<E offset="14" fromy="30" fromx="14" toy="30" tox="21" sentence="Má shuíonn tú ag bhord le flaith, tabhair faoi deara go cúramach céard atá leagtha romhat." errortext="ag bhord" msg="Séimhiú gan ghá">
<E offset="14" fromy="31" fromx="14" toy="31" tox="26" sentence="Bláthaíonn sé amhail bhláth an mhachaire." errortext="amhail bhláth" msg="Séimhiú gan ghá">
<E offset="0" fromy="32" fromx="0" toy="32" tox="8" sentence="An bainim sult as bás an drochdhuine?" errortext="An bainim" msg="Urú ar iarraidh">
<E offset="3" fromy="33" fromx="3" toy="33" tox="21" sentence="Ní féidir an Gaeltacht a choinneáil mar réigiún Gaeilge go náisiúnta gan athrú bunúsach." errortext="féidir an Gaeltacht" msg="Séimhiú ar iarraidh">
<E offset="22" fromy="34" fromx="22" toy="34" tox="37" sentence="Cad é an chomhairle a thug an ochtapas dó?" errortext="thug an ochtapas" msg="Réamhlitir /t/ ar iarraidh">
<E offset="55" fromy="35" fromx="55" toy="35" tox="67" sentence="Chóirigh sé na lampaí le solas a chaitheamh os comhair an coinnleora." errortext="an coinnleora" msg="Séimhiú ar iarraidh">
<E offset="34" fromy="36" fromx="34" toy="36" tox="46" sentence="Comhlánóidh saoránacht an Aontais an saoránacht náisiúnta agus ní ghabhfaidh sí a hionad." errortext="an saoránacht" msg="Réamhlitir /t/ ar iarraidh">
<E offset="49" fromy="37" fromx="49" toy="37" tox="59" sentence="Bíonn na cimí ar a suaimhneas le chéile gan guth an séiléara le clos a thuilleadh." errortext="an séiléara" msg="Réamhlitir /t/ ar iarraidh">
<E offset="40" fromy="38" fromx="40" toy="38" tox="46" sentence="Tá sin ráite cheana féin acu le muintir an tíre seo." errortext="an tíre" msg="Ba chóir duit /na/ a úsáid anseo">
<E offset="68" fromy="39" fromx="68" toy="39" tox="81" sentence="Is é is dóichí go raibh baint ag an eisimirce leis an laghdú i líon an gcainteoirí Gaeilge." errortext="an gcainteoirí" msg="Ba chóir duit /na/ a úsáid anseo">
<E offset="5" fromy="40" fromx="5" toy="40" tox="24" sentence="Ba é an fear an phortaigh a tháinig thart leis na plátaí bia." errortext="an fear an phortaigh" msg="Ní gá leis an alt cinnte anseo">
<E offset="20" fromy="41" fromx="20" toy="41" tox="44" sentence="Tá dhá shiombail ag an bharr gach leathanaigh." errortext="an bharr gach leathanaigh" msg="Ní gá leis an alt cinnte anseo">
<E offset="10" fromy="42" fromx="10" toy="42" tox="22" sentence="Ní bheidh aon buntáiste againn orthu sin." errortext="aon buntáiste" msg="Séimhiú ar iarraidh">
<E offset="0" fromy="43" fromx="0" toy="43" tox="8" sentence="Ar gcaith tú do chiall agus do chéadfaí ar fad?" errortext="Ar gcaith" msg="Séimhiú ar iarraidh">
<E offset="10" fromy="44" fromx="10" toy="44" tox="21" sentence="Ní amháin ár dhá chosa, ach nigh ár lámha!" errortext="ár dhá chosa" msg="Urú ar iarraidh">
<E offset="48" fromy="45" fromx="48" toy="45" tox="55" sentence="Gheobhaimid maoin de gach sórt, agus líonfaimid ár tithe le creach." errortext="ár tithe" msg="Urú ar iarraidh">
<E offset="11" fromy="46" fromx="11" toy="46" tox="18" sentence="Níl aon ní arbh fiú a shantú seachas í." errortext="arbh fiú" msg="Séimhiú ar iarraidh">
<E offset="0" fromy="47" fromx="0" toy="47" tox="7" sentence="Ba maith liom fios a thabhairt anois daoibh." errortext="Ba maith" msg="Séimhiú ar iarraidh">
<E offset="0" fromy="48" fromx="0" toy="48" tox="5" sentence="Ba eol duit go hiomlán m'anam." errortext="Ba eol" msg="Ba chóir duit /b+uaschamóg/ a úsáid anseo">
<E offset="7" fromy="49" fromx="7" toy="49" tox="21" sentence="D'fhan beirt buachaill sa champa." errortext="beirt buachaill" msg="Séimhiú ar iarraidh">
<E offset="7" fromy="50" fromx="7" toy="50" tox="31" sentence="D'fhan beirt bhuachaill cancrach sa champa." errortext="beirt bhuachaill cancrach" msg="Séimhiú ar iarraidh">
<E offset="10" fromy="51" fromx="10" toy="51" tox="23" sentence="Ní amháin bhur dhá chosa, ach nigh bhur lámha!" errortext="bhur dhá chosa" msg="Urú ar iarraidh">
<E offset="28" fromy="52" fromx="28" toy="52" tox="40" sentence="Déanaigí beart leis de réir bhur briathra." errortext="bhur briathra" msg="Urú ar iarraidh">
<E offset="0" fromy="53" fromx="0" toy="53" tox="10" sentence="Cá cuireann tú do thréad ar féarach?" errortext="Cá cuireann" msg="Urú ar iarraidh">
<E offset="0" fromy="54" fromx="0" toy="54" tox="5" sentence="Cá áit a nochtfadh sé é féin ach i mBostún!" errortext="Cá áit" msg="Réamhlitir /h/ ar iarraidh">
<E offset="0" fromy="55" fromx="0" toy="55" tox="6" sentence="Cá chás dúinn bheith ag máinneáil thart anseo?" errortext="Cá chás" msg="Séimhiú gan ghá">
<E offset="0" fromy="56" fromx="0" toy="56" tox="6" sentence="Cár fág tú eisean?" errortext="Cár fág" msg="Ba chóir duit /cá/ a úsáid anseo">
<E offset="0" fromy="57" fromx="0" toy="57" tox="8" sentence="Cár bhfág tú eisean?" errortext="Cár bhfág" msg="Séimhiú ar iarraidh">
<E offset="19" fromy="58" fromx="19" toy="58" tox="20" sentence="Cár fágadh eisean (OK)?" errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha /^OK/ neamhdhóchúil)">
<E offset="0" fromy="59" fromx="0" toy="59" tox="5" sentence="Cé iad na fir seo ag fanacht farat?" errortext="Cé iad" msg="Réamhlitir /h/ ar iarraidh">
<E offset="0" fromy="60" fromx="0" toy="60" tox="4" sentence="Cé an ceart atá agamsa a thuilleadh fós a lorg ar an rí?" errortext="Cé an" msg="Ba chóir duit /cén/ a úsáid anseo">
<E offset="15" fromy="61" fromx="15" toy="61" tox="29" sentence="D'fhoilsigh sí a céad cnuasach filíochta i 1995." errortext="a céad cnuasach" msg="Séimhiú ar iarraidh">
<E offset="20" fromy="62" fromx="20" toy="62" tox="32" sentence="Chuir siad fios orm ceithre uaire ar an tslí sin." errortext="ceithre uaire" msg="Ba chóir duit /huaire/ a úsáid anseo">
<E offset="48" fromy="63" fromx="48" toy="63" tox="59" sentence="Beidh ar Bhord Feidhmiúcháin an tUachtarán agus ceithre ball eile." errortext="ceithre ball" msg="Séimhiú ar iarraidh">
<E offset="0" fromy="64" fromx="0" toy="64" tox="11" sentence="Cén amhránaí is fearr leat?" errortext="Cén amhránaí" msg="Réamhlitir /t/ ar iarraidh">
<E offset="7" fromy="65" fromx="7" toy="65" tox="20" sentence="Bhí an chéad cruinniú den Choimisiún i Ros Muc i nGaeltacht na Gaillimhe." errortext="chéad cruinniú" msg="Séimhiú ar iarraidh">
<E offset="6" fromy="66" fromx="6" toy="66" tox="18" sentence="Tá sé chomh iontach le sneachta dearg." errortext="chomh iontach" msg="Réamhlitir /h/ ar iarraidh">
<E offset="20" fromy="67" fromx="20" toy="67" tox="36" sentence="Chuir mé céad punta chuig an banaltra." errortext="chuig an banaltra" msg="Urú nó séimhiú ar iarraidh">
<E offset="22" fromy="68" fromx="22" toy="68" tox="34" sentence="Níl tú do do sheoladh chuig dhaoine a labhraíonn teanga dhothuigthe." errortext="chuig dhaoine" msg="Séimhiú gan ghá">
<E offset="30" fromy="69" fromx="30" toy="69" tox="41" sentence="Bhí sé cúig bhanlámh ar fhad, cúig banlámh ar leithead." errortext="cúig banlámh" msg="Séimhiú ar iarraidh">
<E offset="18" fromy="70" fromx="18" toy="70" tox="29" sentence="Beirim mo mhionna dar an beart a rinne Dia le mo shinsir." errortext="dar an beart" msg="Urú nó séimhiú ar iarraidh">
<E offset="12" fromy="71" fromx="12" toy="71" tox="23" sentence="Dearbhaím é dar chuthach m'éada i gcoinne na gciníocha eile." errortext="dar chuthach" msg="Séimhiú gan ghá">
<E offset="20" fromy="72" fromx="20" toy="72" tox="35" sentence="Sa dara bliain déag dár braighdeanas, tháinig fear ar a theitheadh." errortext="dár braighdeanas" msg="Urú ar iarraidh">
<E offset="25" fromy="73" fromx="25" toy="73" tox="32" sentence="D'oibrigh mé liom go dtí Dé Aoine." errortext="Dé Aoine" msg="Réamhlitir /h/ ar iarraidh">
<E offset="4" fromy="74" fromx="4" toy="74" tox="14" sentence="Bhí deich tobar fíoruisce agus seachtó crann pailme ann." errortext="deich tobar" msg="Urú ar iarraidh">
<E offset="12" fromy="75" fromx="12" toy="75" tox="24" sentence="Tógfaidh mé do coinnleoir óna ionad, mura ndéana tú aithrí." errortext="do coinnleoir" msg="Séimhiú ar iarraidh">
<E offset="13" fromy="76" fromx="13" toy="76" tox="21" sentence="Is cúis imní don pobal a laghad maoinithe a dhéantar ar Naíscoileanna." errortext="don pobal" msg="Séimhiú ar iarraidh">
<E offset="22" fromy="77" fromx="22" toy="77" tox="26" sentence="Creidim go raibh siad de an thuairim chéanna." errortext="de an" msg="Ba chóir duit /den/ a úsáid anseo">
<E offset="0" fromy="78" fromx="0" toy="78" tox="12" sentence="Tá dhá teanga oifigiúla le stádas bunreachtúil á labhairt sa tír seo." errortext="Tá dhá teanga" msg="Séimhiú ar iarraidh">
<E offset="43" fromy="79" fromx="43" toy="79" tox="47" sentence="Cá bhfuil feoil le fáil agamsa le tabhairt do an mhuintir seo?" errortext="do an" msg="Ba chóir duit /don/ a úsáid anseo">
<E offset="44" fromy="80" fromx="44" toy="80" tox="56" sentence="Is amhlaidh a bheidh freisin do na tagairtí do airteagail." errortext="do airteagail" msg="Ba chóir duit /d+uaschamóg/ a úsáid anseo">
<E offset="40" fromy="81" fromx="40" toy="81" tox="43" sentence="Tá sé de chúram seirbhís a chur ar fáil do a gcustaiméirí i nGaeilge." errortext="do a" msg="Ba chóir duit /dá/ a úsáid anseo">
<E offset="29" fromy="82" fromx="29" toy="82" tox="33" sentence="Seinnigí moladh ar an gcruit do ár nDia." errortext="do ár" msg="Ba chóir duit /dár/ a úsáid anseo">
<E offset="55" fromy="83" fromx="55" toy="83" tox="61" sentence="Tabharfaidh an tUachtarán a óráid ag leath i ndiaidh a dó déag Dé Sathairn." errortext="dó déag" msg="Séimhiú ar iarraidh">
<E offset="21" fromy="84" fromx="21" toy="84" tox="35" sentence="Tá an domhan go léir faoi suaimhneas." errortext="faoi suaimhneas" msg="Séimhiú ar iarraidh">
<E offset="59" fromy="85" fromx="59" toy="85" tox="65" sentence="Caithfidh pobal na Gaeltachta iad féin cinneadh a dhéanamh faoi an Ghaeilge." errortext="faoi an" msg="Ba chóir duit /faoin/ a úsáid anseo">
<E offset="31" fromy="86" fromx="31" toy="86" tox="36" sentence="Cuireann sí a neart mar chrios faoi a coim." errortext="faoi a" msg="Ba chóir duit /faoina/ a úsáid anseo">
<E offset="21" fromy="87" fromx="21" toy="87" tox="27" sentence="Cuireann sé ciníocha faoi ár smacht agus cuireann sé náisiúin faoinár gcosa." errortext="faoi ár" msg="Ba chóir duit /faoinár/ a úsáid anseo">
<E offset="41" fromy="88" fromx="41" toy="88" tox="51" sentence="Tá dualgas ar an gComhairle sin tabhairt faoin cúram seo." errortext="faoin cúram" msg="Urú nó séimhiú ar iarraidh">
<E offset="56" fromy="89" fromx="56" toy="89" tox="68" sentence="Ní bheidh gearán ag duine ar bith faoin gciste fial atá faoinár cúram." errortext="faoinár cúram" msg="Urú ar iarraidh">
<E offset="16" fromy="90" fromx="16" toy="90" tox="30" sentence="Beidh paráid Lá Fhéile Phádraig i mBostún." errortext="Fhéile Phádraig" msg="Séimhiú gan ghá">
<E offset="62" fromy="91" fromx="62" toy="91" tox="63" sentence="Tá Féile Bhealtaine an Oireachtais ar siúl an tseachtain seo (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha /^OK/ neamhdhóchúil)">
<E offset="47" fromy="92" fromx="47" toy="92" tox="57" sentence="Tá ar chumas an duine saol iomlán a chaitheamh gan theanga eile á brú air." errortext="gan theanga" msg="Séimhiú gan ghá">
<E offset="19" fromy="93" fromx="19" toy="93" tox="30" sentence="Tá gruaim mhór orm gan Chaitlín." errortext="gan Chaitlín" msg="Séimhiú gan ghá">
<E offset="67" fromy="94" fromx="67" toy="94" tox="78" sentence="Is stáit ilteangacha iad cuid mhór de na stáit sin atá aonteangach go oifigiúil." errortext="go oifigiúil" msg="Réamhlitir /h/ ar iarraidh">
<E offset="30" fromy="95" fromx="30" toy="95" tox="37" sentence="Ní bheidh bonn comparáide ann go beidh torthaí Dhaonáireamh 2007 ar fáil." errortext="go beidh" msg="Urú ar iarraidh">
<E offset="17" fromy="96" fromx="17" toy="96" tox="25" sentence="Rug sé ar ais mé go dhoras an Teampaill." errortext="go dhoras" msg="Séimhiú gan ghá">
<E offset="16" fromy="97" fromx="16" toy="97" tox="20" sentence="Chuaigh mé suas go an doras cúil a chaisleáin." errortext="go an" msg="Ba chóir duit /go dtí/ a úsáid anseo">
<E offset="12" fromy="98" fromx="12" toy="98" tox="23" sentence="Tar, téanam go dtí bhean na bhfíseanna." errortext="go dtí bhean" msg="Séimhiú gan ghá">
<E offset="15" fromy="99" fromx="15" toy="99" tox="26" sentence="Ba mhaith liom gur bhfágann daoine óga an scoil agus iad ullmhaithe." errortext="gur bhfágann" msg="Ba chóir duit /go/ a úsáid anseo">
<E offset="11" fromy="100" fromx="11" toy="100" tox="19" sentence="Bhraith mé gur fuair mé boladh trom tais uathu." errortext="gur fuair" msg="Ba chóir duit /go/ a úsáid anseo">
<E offset="20" fromy="101" fromx="20" toy="101" tox="28" sentence="An ea nach cás leat gur bhfág mo dheirfiúr an freastal fúmsa i m'aonar?" errortext="gur bhfág" msg="Séimhiú ar iarraidh">
<E offset="10" fromy="102" fromx="10" toy="102" tox="20" sentence="B'fhéidir gurbh fearr é seo duit ná leamhnacht na bó ba mhilse i gcontae Chill Mhantáin." errortext="gurbh fearr" msg="Séimhiú ar iarraidh">
<E offset="34" fromy="103" fromx="34" toy="103" tox="44" sentence="An bhfuil aon uachtar reoite agat i cuisneoir?" errortext="i cuisneoir" msg="Urú ar iarraidh">
<E offset="34" fromy="104" fromx="34" toy="104" tox="45" sentence="An bhfuil aon uachtar reoite agat i chuisneoir?" errortext="i chuisneoir" msg="Urú ar iarraidh">
<E offset="36" fromy="105" fromx="36" toy="105" tox="41" sentence="An bhfuil aon uachtar reoite agaibh i bhur gcuisneoir?" errortext="i bhur" msg="Ba chóir duit /in bhur/ a úsáid anseo">
<E offset="34" fromy="106" fromx="34" toy="106" tox="38" sentence="An bhfuil aon uachtar reoite agat i dhá chuisneoir?" errortext="i dhá" msg="Ba chóir duit /in dhá/ a úsáid anseo">
<E offset="34" fromy="107" fromx="34" toy="107" tox="37" sentence="An bhfuil aon uachtar reoite agat i an chuisneoir?" errortext="i an" msg="Ba chóir duit /sa/ a úsáid anseo">
<E offset="34" fromy="108" fromx="34" toy="108" tox="37" sentence="An bhfuil aon uachtar reoite agat i na cuisneoirí?" errortext="i na" msg="Ba chóir duit /sna/ a úsáid anseo">
<E offset="29" fromy="109" fromx="29" toy="109" tox="31" sentence="An bhfuil aon uachtar reoite i a cuisneoir?" errortext="i a" msg="Ba chóir duit /ina/ a úsáid anseo">
<E offset="36" fromy="110" fromx="36" toy="110" tox="39" sentence="Rinne gach cine é sin sna cathracha i ar lonnaíodar." errortext="i ar" msg="Ba chóir duit /inar/ a úsáid anseo">
<E offset="29" fromy="111" fromx="29" toy="111" tox="32" sentence="An bhfuil aon uachtar reoite i ár gcuisneoir?" errortext="i ár" msg="Ba chóir duit /inár/ a úsáid anseo">
<E offset="30" fromy="112" fromx="30" toy="112" tox="34" sentence="Thug sé seo deis dom breathnú in mo thimpeall." errortext="in mo" msg="Ba chóir duit /i/ a úsáid anseo">
<E offset="12" fromy="113" fromx="12" toy="113" tox="25" sentence="Tá beirfean inár craiceann faoi mar a bheimis i sorn." errortext="inár craiceann" msg="Urú ar iarraidh">
<E offset="51" fromy="114" fromx="51" toy="114" tox="61" sentence="Is tuar dóchais é an méid dul chun cinn atá déanta le bhlianta beaga." errortext="le bhlianta" msg="Séimhiú gan ghá">
<E offset="39" fromy="115" fromx="39" toy="115" tox="43" sentence="D'fhéadfadh tábhacht a bheith ag baint le an gcéad toisc díobh sin." errortext="le an" msg="Ba chóir duit /leis an/ a úsáid anseo">
<E offset="50" fromy="116" fromx="50" toy="116" tox="54" sentence="Molann an Coimisiún go maoineofaí scéim chun tacú le na pobail sin." errortext="le na" msg="Ba chóir duit /leis na/ a úsáid anseo">
<E offset="34" fromy="117" fromx="34" toy="117" tox="37" sentence="Labhraíodh gach duine an fhírinne le a chomharsa." errortext="le a" msg="Ba chóir duit /lena/ a úsáid anseo">
<E offset="28" fromy="118" fromx="28" toy="118" tox="32" sentence="Beir i do láimh ar an tslat le ar bhuail tú an abhainn, agus seo leat." errortext="le ar" msg="Ba chóir duit /lenar/ a úsáid anseo">
<E offset="35" fromy="119" fromx="35" toy="119" tox="39" sentence="Ba mhaith liom buíochas a ghlacadh le ár bhfoireann riaracháin." errortext="le ár" msg="Ba chóir duit /lenár/ a úsáid anseo">
<E offset="20" fromy="120" fromx="20" toy="120" tox="25" sentence="Tógann siad cuid de le iad féin a théamh." errortext="le iad" msg="Réamhlitir /h/ ar iarraidh">
<E offset="27" fromy="121" fromx="27" toy="121" tox="42" sentence="Tá do scrios chomh leathan leis an farraige." errortext="leis an farraige" msg="Urú nó séimhiú ar iarraidh">
<E offset="26" fromy="122" fromx="26" toy="122" tox="36" sentence="Is linne í ar ndóigh agus lenár clann." errortext="lenár clann" msg="Urú ar iarraidh">
<E offset="0" fromy="123" fromx="0" toy="123" tox="8" sentence="Má tugann rí breith ar na boicht le cothromas, bunófar a ríchathaoir go brách." errortext="Má tugann" msg="Séimhiú ar iarraidh">
<E offset="28" fromy="124" fromx="28" toy="124" tox="37" sentence="Roghnaítear an bhliain 1961 mar pointe tosaigh don anailís." errortext="mar pointe" msg="Séimhiú ar iarraidh">
<E offset="9" fromy="125" fromx="9" toy="125" tox="20" sentence="Comhlíon mo aitheanta agus mairfidh tú beo." errortext="mo aitheanta" msg="Ba chóir duit /m+uaschamóg/ a úsáid anseo">
<E offset="15" fromy="126" fromx="15" toy="126" tox="26" sentence="Ceapadh mise i mo bolscaire." errortext="mo bolscaire" msg="Séimhiú ar iarraidh">
<E offset="34" fromy="127" fromx="34" toy="127" tox="45" sentence="Tá mé ag sclábhaíocht ag iarraidh mo dhá gasúr a chur trí scoil." errortext="mo dhá gasúr" msg="Séimhiú ar iarraidh">
<E offset="0" fromy="128" fromx="0" toy="128" tox="10" sentence="Mura tagann aon duine i gcabhair orainn, rachaimid anonn chugaibh." errortext="Mura tagann" msg="Urú ar iarraidh">
<E offset="0" fromy="129" fromx="0" toy="129" tox="17" sentence="Murar chruthaítear lá agus oíche... teilgim uaim sliocht Iacóib." errortext="Murar chruthaítear" msg="Séimhiú gan ghá">
<E offset="0" fromy="130" fromx="0" toy="130" tox="15" sentence="Murar gcruthaigh mise lá agus oíche... teilgim uaim sliocht Iacóib." errortext="Murar gcruthaigh" msg="Séimhiú ar iarraidh">
<E offset="37" fromy="131" fromx="37" toy="131" tox="42" sentence="An bhfuil aon uachtar reoite ag fear na bád?" errortext="na bád" msg="Urú ar iarraidh">
<E offset="18" fromy="132" fromx="18" toy="132" tox="27" sentence="Is mór ag náisiún na Éireann a choibhneas speisialta le daoine de bhunadh na hÉireann atá ina gcónaí ar an gcoigríoch." errortext="na Éireann" msg="Réamhlitir /h/ ar iarraidh">
<E offset="44" fromy="133" fromx="44" toy="133" tox="58" sentence="Chuir an Coimisiún féin comhfhreagras chuig na eagraíochtaí seo ag lorg eolais faoina ngníomhaíochtaí." errortext="na eagraíochtaí" msg="Réamhlitir /h/ ar iarraidh">
<E offset="0" fromy="134" fromx="0" toy="134" tox="10" sentence="Ná iompaígí chun na n-íol, agus ná dealbhaígí déithe de mhiotal." errortext="Ná iompaígí" msg="Réamhlitir /h/ ar iarraidh">
<E offset="43" fromy="135" fromx="43" toy="135" tox="50" sentence="Is fearr de bhéile luibheanna agus grá leo ná mhart méith agus gráin leis." errortext="ná mhart" msg="Séimhiú gan ghá">
<E offset="0" fromy="136" fromx="0" toy="136" tox="12" sentence="Nach bainfidh mé uaidh an méid a ghoid sé uaim?" errortext="Nach bainfidh" msg="Urú ar iarraidh">
<E offset="23" fromy="137" fromx="23" toy="137" tox="33" sentence="Rinneadh an roinnt don naoi treibh go leith ar cranna." errortext="naoi treibh" msg="Urú ar iarraidh">
<E offset="44" fromy="138" fromx="44" toy="138" tox="57" sentence="Tháinig na bróga chomh fada siar le haimsir Naomh Phádraig féin." errortext="Naomh Phádraig" msg="Séimhiú gan ghá">
<E offset="0" fromy="139" fromx="0" toy="139" tox="7" sentence="Nár breá liom claíomh a bheith agam i mo ghlac!" errortext="Nár breá" msg="Séimhiú ar iarraidh">
<E offset="0" fromy="140" fromx="0" toy="140" tox="13" sentence="Nár bhfreagair sé thú, focal ar fhocal." errortext="Nár bhfreagair" msg="Séimhiú ar iarraidh">
<E offset="43" fromy="141" fromx="43" toy="141" tox="54" sentence="Feicimid gur de dheasca a n-easumhlaíochta nárbh féidir leo dul isteach ann." errortext="nárbh féidir" msg="Séimhiú ar iarraidh">
<E offset="0" fromy="142" fromx="0" toy="142" tox="11" sentence="Ní féadfaidh a gcuid airgid ná óir iad a shábháil." errortext="Ní féadfaidh" msg="Séimhiú ar iarraidh">
<E offset="0" fromy="143" fromx="0" toy="143" tox="5" sentence="Ní iad sin do phíopaí ar an tábla!" errortext="Ní iad" msg="Réamhlitir /h/ ar iarraidh">
<E offset="23" fromy="144" fromx="23" toy="144" tox="36" sentence="Bhí an méid sin airgid níba luachmhar dúinn ná maoin an domhain." errortext="níba luachmhar" msg="Ba chóir duit an bhreischéim a úsáid anseo">
<E offset="14" fromy="145" fromx="14" toy="145" tox="20" sentence="Eisean beagán níb óga ná mise." errortext="níb óga" msg="Ba chóir duit an bhreischéim a úsáid anseo">
<E offset="14" fromy="146" fromx="14" toy="146" tox="22" sentence="Eisean beagán níba óige ná mise." errortext="níba óige" msg="Ba chóir duit /níb/ a úsáid anseo">
<E offset="22" fromy="147" fromx="22" toy="147" tox="32" sentence="Bhí na páistí ag éirí níba tréine." errortext="níba tréine" msg="Séimhiú ar iarraidh">
<E offset="35" fromy="148" fromx="20" toy="148" tox="32" sentence="&quot;Tá,&quot; ar sise, &quot;ach níor fhacthas é sin.&quot;" errortext="níor fhacthas" msg="Ba chóir duit /ní/ a úsáid anseo">
<E offset="0" fromy="149" fromx="0" toy="149" tox="6" sentence="Níor gá do dheoraí riamh codladh sa tsráid; Bhí mo dhoras riamh ar leathadh." errortext="Níor gá" msg="Séimhiú ar iarraidh">
<E offset="35" fromy="150" fromx="20" toy="150" tox="29" sentence="&quot;Tá,&quot; ar sise, &quot;ach níor fuair muid aon ocras fós." errortext="níor fuair" msg="Ba chóir duit /ní/ a úsáid anseo">
<E offset="0" fromy="151" fromx="0" toy="151" tox="9" sentence="Níor mbain sé leis an dream a bhí i gcogar ceilge." errortext="Níor mbain" msg="Séimhiú ar iarraidh">
<E offset="0" fromy="152" fromx="0" toy="152" tox="12" sentence="Níorbh foláir dó éisteacht a thabhairt dom." errortext="Níorbh foláir" msg="Séimhiú ar iarraidh">
<E offset="10" fromy="153" fromx="10" toy="153" tox="19" sentence="Ach anois ó cuimhním air, bhí ardán coincréite sa pháirc." errortext="ó cuimhním" msg="Séimhiú ar iarraidh">
<E offset="29" fromy="154" fromx="29" toy="154" tox="34" sentence="Tabhair an t-ordú seo leanas ó béal." errortext="ó béal" msg="Séimhiú ar iarraidh">
<E offset="21" fromy="155" fromx="21" toy="155" tox="24" sentence="Bíodh bhur ngrá saor ó an gcur i gcéill." errortext="ó an" msg="Ba chóir duit /ón/ a úsáid anseo">
<E offset="4" fromy="156" fromx="4" toy="156" tox="13" sentence="Bhí ocht tábla ar fad ar a maraídís na híobairtí." errortext="ocht tábla" msg="Urú ar iarraidh">
<E offset="21" fromy="157" fromx="21" toy="157" tox="26" sentence="Bíodh bhur ngrá saor ón cur i gcéill." errortext="ón cur" msg="Urú nó séimhiú ar iarraidh">
<E offset="13" fromy="158" fromx="13" toy="158" tox="15" sentence="Amharcann sé ó a ionad cónaithe ar gach aon neach dá maireann ar talamh." errortext="ó a" msg="Ba chóir duit /óna/ a úsáid anseo">
<E offset="43" fromy="159" fromx="43" toy="159" tox="46" sentence="Seo iad a gcéimeanna de réir na n-áiteanna ó ar thosaíodar." errortext="ó ar" msg="Ba chóir duit /ónar/ a úsáid anseo">
<E offset="29" fromy="160" fromx="29" toy="160" tox="32" sentence="Agus rinne sé ár bhfuascailt ó ár naimhde." errortext="ó ár" msg="Ba chóir duit /ónár/ a úsáid anseo">
<E offset="28" fromy="161" fromx="28" toy="161" tox="36" sentence="Bhíodh súil in airde againn ónár túir faire." errortext="ónár túir" msg="Urú ar iarraidh">
<E offset="44" fromy="162" fromx="44" toy="162" tox="55" sentence="Tá do ghéaga spréite ar bhraillín ghléigeal os fharraige faoileán." errortext="os fharraige" msg="Séimhiú gan ghá">
<E offset="23" fromy="163" fromx="23" toy="163" tox="26" sentence="Uaidh féin, b'fhéidir, pé é féin." errortext="pé é" msg="Réamhlitir /h/ ar iarraidh">
<E offset="23" fromy="164" fromx="23" toy="164" tox="36" sentence="Agus tháinig scéin air roimh an pobal seo ar a líonmhaire." errortext="roimh an pobal" msg="Urú nó séimhiú ar iarraidh">
<E offset="18" fromy="165" fromx="18" toy="165" tox="29" sentence="Is gaiste é eagla roimh daoine." errortext="roimh daoine" msg="Séimhiú ar iarraidh">
<E offset="34" fromy="166" fromx="34" toy="166" tox="45" sentence="An bhfuil aon uachtar reoite agat sa cuisneoir?" errortext="sa cuisneoir" msg="Séimhiú ar iarraidh">
<E offset="34" fromy="167" fromx="34" toy="167" tox="43" sentence="An bhfuil aon uachtar reoite agat sa seamair?" errortext="sa seamair" msg="Réamhlitir /t/ ar iarraidh">
<E offset="44" fromy="168" fromx="44" toy="168" tox="45" sentence="An bhfuil aon uachtar reoite agat sa scoil (OK)?" errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha /^OK/ neamhdhóchúil)">
<E offset="47" fromy="169" fromx="47" toy="169" tox="48" sentence="An bhfuil aon uachtar reoite agat sa samhradh (OK)?" errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha /^OK/ neamhdhóchúil)">
<E offset="28" fromy="170" fromx="28" toy="170" tox="41" sentence="Tá sé bráthair de chuid Ord San Phroinsias." errortext="San Phroinsias" msg="Séimhiú gan ghá">
<E offset="0" fromy="171" fromx="0" toy="171" tox="9" sentence="San fásach cuirfidh mé crainn chéadrais." errortext="San fásach" msg="Séimhiú ar iarraidh">
<E offset="34" fromy="172" fromx="34" toy="172" tox="44" sentence="An bhfuil aon uachtar reoite agat san foraois?" errortext="san foraois" msg="Séimhiú ar iarraidh">
<E offset="34" fromy="173" fromx="34" toy="173" tox="43" sentence="An bhfuil aon uachtar reoite agat sa oighear?" errortext="sa oighear" msg="Ba chóir duit /san/ a úsáid anseo">
<E offset="35" fromy="174" fromx="35" toy="174" tox="42" sentence="Tugaimid faoi abhainn na Sionainne san bhád locha ó Ros Comáin." errortext="san bhád" msg="Ba chóir duit /sa/ a úsáid anseo">
<E offset="47" fromy="175" fromx="47" toy="175" tox="54" sentence="Ní féidir iad a sheinm le snáthaid ach cúig nó sé uaire." errortext="sé uaire" msg="Ba chóir duit /huaire/ a úsáid anseo">
<E offset="67" fromy="176" fromx="67" toy="176" tox="68" sentence="Dúirt sé uair amháin nach raibh áit eile ar mhaith leis cónaí ann (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha /^OK/ neamhdhóchúil)">
<E offset="17" fromy="177" fromx="17" toy="177" tox="32" sentence="Céard atá ann ná sé cathaoirleach coiste." errortext="sé cathaoirleach" msg="Séimhiú ar iarraidh">
<E offset="32" fromy="178" fromx="32" toy="178" tox="46" sentence="Cuireadh boscaí ticeála isteach seachas bhoscaí le freagraí a scríobh isteach." errortext="seachas bhoscaí" msg="Séimhiú gan ghá">
<E offset="25" fromy="179" fromx="25" toy="179" tox="36" sentence="Tá seacht lampa air agus seacht píopa ar gach ceann díobh." errortext="seacht píopa" msg="Urú ar iarraidh">
<E offset="50" fromy="180" fromx="50" toy="180" tox="61" sentence="Tá ar a laghad ceithre ní sa litir a chuir scaoll sna oifigigh." errortext="sna oifigigh" msg="Réamhlitir /h/ ar iarraidh">
<E offset="30" fromy="181" fromx="30" toy="181" tox="43" sentence="Iompróidh siad thú lena lámha sula bhuailfeá do chos in aghaidh cloiche." errortext="sula bhuailfeá" msg="Urú ar iarraidh">
<E offset="4" fromy="182" fromx="4" toy="182" tox="15" sentence="Ach sular sroich sé, dúirt sí: &quot;Dúnaigí an doras air!&quot;" errortext="sular sroich" msg="Séimhiú ar iarraidh">
<E offset="40" fromy="183" fromx="40" toy="183" tox="51" sentence="Chuir iad ina suí mar a raibh onóir acu thar an cuid eile a fuair cuireadh." errortext="thar an cuid" msg="Urú nó séimhiú ar iarraidh">
<E offset="9" fromy="184" fromx="9" toy="184" tox="17" sentence="Timpeall trí uaire a chloig ina dhiaidh sin tháinig an bhean isteach." errortext="trí uaire" msg="Ba chóir duit /huaire/ a úsáid anseo">
<E offset="58" fromy="185" fromx="58" toy="185" tox="62" sentence="Scríobhaim chugaibh mar gur maitheadh daoibh bhur bpeacaí trí a ainm." errortext="trí a" msg="Ba chóir duit /trína/ a úsáid anseo">
<E offset="31" fromy="186" fromx="31" toy="186" tox="36" sentence="Ní fhillfidh siad ar an ngeata trí ar ghabh siad isteach." errortext="trí ar" msg="Ba chóir duit /trínar/ a úsáid anseo">
<E offset="33" fromy="187" fromx="33" toy="187" tox="38" sentence="Beirimid an bua go caithréimeach trí an té úd a thug grá dúinn." errortext="trí an" msg="Ba chóir duit /tríd an/ a úsáid anseo">
<E offset="49" fromy="188" fromx="49" toy="188" tox="54" sentence="Coinníodh lenár sála sa chaoi nárbh fhéidir siúl trí ár sráideanna." errortext="trí ár" msg="Ba chóir duit /trínár/ a úsáid anseo">
<E offset="15" fromy="189" fromx="15" toy="189" tox="22" sentence="Gabhfaidh siad trí muir na hÉigipte." errortext="trí muir" msg="Séimhiú ar iarraidh">
<E offset="36" fromy="190" fromx="36" toy="190" tox="42" sentence="Feidhmeoidh an ciste coimisiúnaithe tríd na foilsitheoirí go príomha." errortext="tríd na" msg="Ba chóir duit /trí na/ a úsáid anseo">
<E offset="4" fromy="191" fromx="4" toy="191" tox="16" sentence="Mar trínár peacaí, tá do phobal ina ábhar gáire ag cách máguaird orainn." errortext="trínár peacaí" msg="Urú ar iarraidh">
<E offset="17" fromy="192" fromx="17" toy="192" tox="28" sentence="Idir dhá sholas, um tráthnóna, faoi choim na hoíche agus sa dorchadas." errortext="um tráthnóna" msg="Séimhiú ar iarraidh">
<E offset="38" fromy="193" fromx="38" toy="193" tox="39" sentence="Tá sé-- tá sé- mo ---shin-seanathair (OK)." errortext="OK" msg="Is féidir gur focal iasachta é seo (tá na litreacha /^OK/ neamhdhóchúil)">
<E offset="16" fromy="194" fromx="16" toy="194" tox="22" sentence="Maidin lá ar na mhárach thug a fhear gaoil cuairt air." errortext="mhárach" msg="Ní úsáidtear an focal seo ach san abairtín /arna mhárach/ de ghnáth">
<E offset="23" fromy="195" fromx="23" toy="195" tox="24" sentence="Bhain na toibreacha le re eile agus le dream daoine atá imithe." errortext="re" msg="Ní úsáidtear an focal seo ach san abairtín /gach re/ de ghnáth">
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
