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
Ní raibh líon mór daoine bainteach leis an scaifte a bhí ag iarraidh mioscais a chothú.
Ach thosnaíos-sa ag léamh agus bhog mé isteach ionam féin.
Tabhair go leor leor de na na rudaí seo do do chara, a Chaoimhín.
Chuaigh sí in olcas ina dhiaidh sin agus bhí an-imní orthu.
Tharla sé seo ar lá an-mífheiliúnach, an Déardaoin.
Ní maith liom na daoine míintleachtúla.
Trí chomhtharlúint, bhí siad sa tuaisceart ag an am.
Sílim nárbh ea, agus is docha nach bhfuil i gceist ach easpa smaoinimh.
Tá súil le feabhas nuair a thosóidh airgead ag teacht isteach ó ola agus gás i mBearna Timor.
Beidh nuachtáin shuaracha i ngreim cé nach mbeadh cinsireacht den droch-chinéal i gceist.
Bhí sé páirteach sa chéad léiriú poiblí de Riverdance.
Beidh an tionchar le mothú níos mó i gcás comhlachtaí Éireannacha mar gur mionairgeadra é an punt.
Bhí an dream dí-armtha ag iarraidh a gcuid gunnaí.
An bhfuil ayn uachtar roeite agattt?
Bíonn an geál ag satailt ar an dubh.
Ach bhí mé ag leanúint ar aghaidh an t-am ar fad leis.
Nach holc an mhaise duit a bheith ag magadh.
Ba hiad na hamhráin i dtosach ba chúis leis.
Ba iad na trí háit iad Bostún, Baile Átha Cliath agus Nua Eabhrac.
Sa dara alt, déan cur síos ar a bhfaca siad sa Spáinn.
Oirfeadh síol áitiúil níos fearr ná an síol a húsáidtear go minic.
Tá ceacht stairiúil uathúil do chuairteoirí san t-ionad seo.
In Éirinn chaitheann breis is 30 faoin gcéad de mhná toitíní.
Tá sé riachtanach ar mhaithe le feidhmiú an phlean a bheidh ceaptha ag an eagraíocht ceannasach.
Tá na lachain slachtmhara ar eitilt.
Tá an Rialtas tar éis áit na Gaeilge i saol na tíre a ceistiú.
Bhíodar ag rá ar an aonach gur agamsa a bhí na huain ab fearr.
Ní bheidh ach mhallacht i ndán dó ó na ciníocha agus fuath ó na náisiúin.
An bhfuil aon uachtar reoite ar an cuntar?
Má shuíonn tú ag bhord le flaith, tabhair faoi deara go cúramach céard atá leagtha romhat.
Bláthaíonn sé amhail bhláth an mhachaire.
An bainim sult as bás an drochdhuine?
Ní féidir an Gaeltacht a choinneáil mar réigiún Gaeilge go náisiúnta gan athrú bunúsach.
Cad é an chomhairle a thug an ochtapas dó?
Chóirigh sé na lampaí le solas a chaitheamh os comhair an coinnleora.
Comhlánóidh saoránacht an Aontais an saoránacht náisiúnta agus ní ghabhfaidh sí a hionad.
Bíonn na cimí ar a suaimhneas le chéile gan guth an séiléara le clos a thuilleadh.
Tá sin ráite cheana féin acu le muintir an tíre seo.
Is é is dóichí go raibh baint ag an eisimirce leis an laghdú i líon an gcainteoirí Gaeilge.
Ba é an fear an phortaigh a tháinig thart leis na plátaí bia.
Tá dhá shiombail ag an bharr gach leathanaigh.
Ní bheidh aon buntáiste againn orthu sin.
Ar gcaith tú do chiall agus do chéadfaí ar fad?
Ní amháin ár dhá chosa, ach nigh ár lámha!
Gheobhaimid maoin de gach sórt, agus líonfaimid ár tithe le creach.
Níl aon ní arbh fiú a shantú seachas í.
Ba maith liom fios a thabhairt anois daoibh.
Ba eol duit go hiomlán m'anam.
D'fhan beirt buachaill sa champa.
D'fhan beirt bhuachaill cancrach sa champa.
Ní amháin bhur dhá chosa, ach nigh bhur lámha!
Déanaigí beart leis de réir bhur briathra.
Cá cuireann tú do thréad ar féarach?
Cá áit a nochtfadh sé é féin ach i mBostún!
Cá chás dúinn bheith ag máinneáil thart anseo?
Cár fág tú eisean?
Cár bhfág tú eisean?
Cár fágadh eisean (OK)?
Cé iad na fir seo ag fanacht farat?
Cé an ceart atá agamsa a thuilleadh fós a lorg ar an rí?
D'fhoilsigh sí a céad cnuasach filíochta i 1995.
Chuir siad fios orm ceithre uaire ar an tslí sin.
Beidh ar Bhord Feidhmiúcháin an tUachtarán agus ceithre ball eile.
Cén amhránaí is fearr leat?
Bhí an chéad cruinniú den Choimisiún i Ros Muc i nGaeltacht na Gaillimhe.
Tá sé chomh iontach le sneachta dearg.
Chuir mé céad punta chuig an banaltra.
Níl tú do do sheoladh chuig dhaoine a labhraíonn teanga dhothuigthe.
Bhí sé cúig bhanlámh ar fhad, cúig banlámh ar leithead.
Beirim mo mhionna dar an beart a rinne Dia le mo shinsir.
Dearbhaím é dar chuthach m'éada i gcoinne na gciníocha eile.
Sa dara bliain déag dár braighdeanas, tháinig fear ar a theitheadh.
D'oibrigh mé liom go dtí Dé Aoine.
Bhí deich tobar fíoruisce agus seachtó crann pailme ann.
Tógfaidh mé do coinnleoir óna ionad, mura ndéana tú aithrí.
Is cúis imní don pobal a laghad maoinithe a dhéantar ar Naíscoileanna.
Creidim go raibh siad de an thuairim chéanna.
Tá dhá teanga oifigiúla le stádas bunreachtúil á labhairt sa tír seo.
Cá bhfuil feoil le fáil agamsa le tabhairt do an mhuintir seo?
Is amhlaidh a bheidh freisin do na tagairtí do airteagail.
Tá sé de chúram seirbhís a chur ar fáil do a gcustaiméirí i nGaeilge.
Seinnigí moladh ar an gcruit do ár nDia.
Tabharfaidh an tUachtarán a óráid ag leath i ndiaidh a dó déag Dé Sathairn.
Tá an domhan go léir faoi suaimhneas.
Caithfidh pobal na Gaeltachta iad féin cinneadh a dhéanamh faoi an Ghaeilge.
Cuireann sí a neart mar chrios faoi a coim.
Cuireann sé ciníocha faoi ár smacht agus cuireann sé náisiúin faoinár gcosa.
Tá dualgas ar an gComhairle sin tabhairt faoin cúram seo.
Ní bheidh gearán ag duine ar bith faoin gciste fial atá faoinár cúram.
Beidh paráid Lá Fhéile Phádraig i mBostún.
Tá Féile Bhealtaine an Oireachtais ar siúl an tseachtain seo (OK).
Tá ar chumas an duine saol iomlán a chaitheamh gan theanga eile á brú air.
Tá gruaim mhór orm gan Chaitlín.
Is stáit ilteangacha iad cuid mhór de na stáit sin atá aonteangach go oifigiúil.
Ní bheidh bonn comparáide ann go beidh torthaí Dhaonáireamh 2007 ar fáil.
Rug sé ar ais mé go dhoras an Teampaill.
Chuaigh mé suas go an doras cúil a chaisleáin.
Tar, téanam go dtí bhean na bhfíseanna.
Ba mhaith liom gur bhfágann daoine óga an scoil agus iad ullmhaithe.
Bhraith mé gur fuair mé boladh trom tais uathu.
An ea nach cás leat gur bhfág mo dheirfiúr an freastal fúmsa i m'aonar?
B'fhéidir gurbh fearr é seo duit ná leamhnacht na bó ba mhilse i gcontae Chill Mhantáin.
An bhfuil aon uachtar reoite agat i cuisneoir?
An bhfuil aon uachtar reoite agat i chuisneoir?
An bhfuil aon uachtar reoite agaibh i bhur gcuisneoir?
An bhfuil aon uachtar reoite agat i dhá chuisneoir?
An bhfuil aon uachtar reoite agat i an chuisneoir?
An bhfuil aon uachtar reoite agat i na cuisneoirí?
An bhfuil aon uachtar reoite i a cuisneoir?
Rinne gach cine é sin sna cathracha i ar lonnaíodar.
An bhfuil aon uachtar reoite i ár gcuisneoir?
Thug sé seo deis dom breathnú in mo thimpeall.
Tá beirfean inár craiceann faoi mar a bheimis i sorn.
Is tuar dóchais é an méid dul chun cinn atá déanta le bhlianta beaga.
D'fhéadfadh tábhacht a bheith ag baint le an gcéad toisc díobh sin.
Molann an Coimisiún go maoineofaí scéim chun tacú le na pobail sin.
Labhraíodh gach duine an fhírinne le a chomharsa.
Beir i do láimh ar an tslat le ar bhuail tú an abhainn, agus seo leat.
Ba mhaith liom buíochas a ghlacadh le ár bhfoireann riaracháin.
Tógann siad cuid de le iad féin a théamh.
Tá do scrios chomh leathan leis an farraige.
Is linne í ar ndóigh agus lenár clann.
Má tugann rí breith ar na boicht le cothromas, bunófar a ríchathaoir go brách.
Roghnaítear an bhliain 1961 mar pointe tosaigh don anailís.
Comhlíon mo aitheanta agus mairfidh tú beo.
Ceapadh mise i mo bolscaire.
Tá mé ag sclábhaíocht ag iarraidh mo dhá gasúr a chur trí scoil. 
Mura tagann aon duine i gcabhair orainn, rachaimid anonn chugaibh.
Murar chruthaítear lá agus oíche... teilgim uaim sliocht Iacóib.
Murar gcruthaigh mise lá agus oíche... teilgim uaim sliocht Iacóib.
An bhfuil aon uachtar reoite ag fear na bád?
Is mór ag náisiún na Éireann a choibhneas speisialta le daoine de bhunadh na hÉireann atá ina gcónaí ar an gcoigríoch.
Chuir an Coimisiún féin comhfhreagras chuig na eagraíochtaí seo ag lorg eolais faoina ngníomhaíochtaí.
Ná iompaígí chun na n-íol, agus ná dealbhaígí déithe de mhiotal.
Is fearr de bhéile luibheanna agus grá leo ná mhart méith agus gráin leis.
Nach bainfidh mé uaidh an méid a ghoid sé uaim?
Rinneadh an roinnt don naoi treibh go leith ar cranna.
Tháinig na bróga chomh fada siar le haimsir Naomh Phádraig féin.
Nár breá liom claíomh a bheith agam i mo ghlac!
Nár bhfreagair sé thú, focal ar fhocal.
Feicimid gur de dheasca a n-easumhlaíochta nárbh féidir leo dul isteach ann.
Ní féadfaidh a gcuid airgid ná óir iad a shábháil.
Ní iad sin do phíopaí ar an tábla!
Bhí an méid sin airgid níba luachmhar dúinn ná maoin an domhain.
Eisean beagán níb óga ná mise.
Eisean beagán níba óige ná mise.
Bhí na páistí ag éirí níba tréine.
"Tá," ar sise, "ach níor fhacthas é sin."
Níor gá do dheoraí riamh codladh sa tsráid; Bhí mo dhoras riamh ar leathadh.
"Tá," ar sise, "ach níor fuair muid aon ocras fós.
Níor mbain sé leis an dream a bhí i gcogar ceilge.
Níorbh foláir dó éisteacht a thabhairt dom.
Ach anois ó cuimhním air, bhí ardán coincréite sa pháirc.
Tabhair an t-ordú seo leanas ó béal.
Bíodh bhur ngrá saor ó an gcur i gcéill.
Bhí ocht tábla ar fad ar a maraídís na híobairtí.
Bíodh bhur ngrá saor ón cur i gcéill.
Amharcann sé ó a ionad cónaithe ar gach aon neach dá maireann ar talamh.
Seo iad a gcéimeanna de réir na n-áiteanna ó ar thosaíodar.
Agus rinne sé ár bhfuascailt ó ár naimhde.
Bhíodh súil in airde againn ónár túir faire.
Tá do ghéaga spréite ar bhraillín ghléigeal os fharraige faoileán.
Uaidh féin, b'fhéidir, pé é féin.
Agus tháinig scéin air roimh an pobal seo ar a líonmhaire.
Is gaiste é eagla roimh daoine.
An bhfuil aon uachtar reoite agat sa cuisneoir?
An bhfuil aon uachtar reoite agat sa seamair?
An bhfuil aon uachtar reoite agat sa scoil (OK)?
An bhfuil aon uachtar reoite agat sa samhradh (OK)?
Tá sé bráthair de chuid Ord San Phroinsias.
San fásach cuirfidh mé crainn chéadrais.
An bhfuil aon uachtar reoite agat san foraois?
An bhfuil aon uachtar reoite agat sa oighear?
Tugaimid faoi abhainn na Sionainne san bhád locha ó Ros Comáin.
Ní féidir iad a sheinm le snáthaid ach cúig nó sé uaire.
Dúirt sé uair amháin nach raibh áit eile ar mhaith leis cónaí ann (OK).
Céard atá ann ná sé cathaoirleach coiste.
Cuireadh boscaí ticeála isteach seachas bhoscaí le freagraí a scríobh isteach.
Tá seacht lampa air agus seacht píopa ar gach ceann díobh.
Tá ar a laghad ceithre ní sa litir a chuir scaoll sna oifigigh.
Iompróidh siad thú lena lámha sula bhuailfeá do chos in aghaidh cloiche.
Ach sular sroich sé, dúirt sí: "Dúnaigí an doras air!"
Chuir iad ina suí mar a raibh onóir acu thar an cuid eile a fuair cuireadh.
Timpeall trí uaire a chloig ina dhiaidh sin tháinig an bhean isteach.
Scríobhaim chugaibh mar gur maitheadh daoibh bhur bpeacaí trí a ainm.
Ní fhillfidh siad ar an ngeata trí ar ghabh siad isteach.
Beirimid an bua go caithréimeach trí an té úd a thug grá dúinn.
Coinníodh lenár sála sa chaoi nárbh fhéidir siúl trí ár sráideanna.
Gabhfaidh siad trí muir na hÉigipte.
Feidhmeoidh an ciste coimisiúnaithe tríd na foilsitheoirí go príomha.
Mar trínár peacaí, tá do phobal ina ábhar gáire ag cách máguaird orainn.
Idir dhá sholas, um tráthnóna, faoi choim na hoíche agus sa dorchadas.
Tá sé-- tá sé- mo ---shin-seanathair (OK).
Maidin lá ar na mhárach thug a fhear gaoil cuairt air.
Bhain na toibreacha le re eile agus le dream daoine atá imithe.
EOF

my $results = <<'RESEOF';
<E offset="43" fromy="1" fromx="43" toy="1" tox="49" sentence="NÃ­ raibh lÃ­on mÃ³r daoine bainteach leis an scaifte a bhÃ­ ag iarraidh mioscais a chothÃº." errortext="scaifte" msg="Foirm neamhchaighdeÃ¡nach de /scata/">
<E offset="4" fromy="2" fromx="4" toy="2" tox="15" sentence="Ach thosnaÃ­os-sa ag lÃ©amh agus bhog mÃ© isteach ionam fÃ©in." errortext="thosnaÃ­os-sa" msg="Foirm neamhchaighdeÃ¡nach de /thosnaigh (thosaigh)/">
<E offset="24" fromy="3" fromx="24" toy="3" tox="28" sentence="Tabhair go leor leor de na na rudaÃ­ seo do do chara, a ChaoimhÃ­n." errortext="na na" msg="Focal cÃ©anna faoi dhÃ³">
<E offset="45" fromy="4" fromx="45" toy="4" tox="51" sentence="Chuaigh sÃ­ in olcas ina dhiaidh sin agus bhÃ­ an-imnÃ­ orthu." errortext="an-imnÃ­" msg="Focal anaithnid ach bunaithe ar /imnÃ­/ is dÃ³cha">
<E offset="20" fromy="5" fromx="20" toy="5" tox="35" sentence="Tharla sÃ© seo ar lÃ¡ an-mÃ­fheiliÃºnach, an DÃ©ardaoin." errortext="an-mÃ­fheiliÃºnach" msg="Bunaithe go mÃ­cheart ar an bhfrÃ©amh /mÃ­fheiliÃºnach/">
<E offset="24" fromy="6" fromx="24" toy="6" tox="37" sentence="NÃ­ maith liom na daoine mÃ­intleachtÃºla." errortext="mÃ­intleachtÃºla" msg="Bunaithe go mÃ­cheart ar an bhfrÃ©amh /intleachtÃºla (intleachtacha, intleachtaÃ­)/">
<E offset="4" fromy="7" fromx="4" toy="7" tox="17" sentence="TrÃ­ chomhtharlÃºint, bhÃ­ siad sa tuaisceart ag an am." errortext="chomhtharlÃºint" msg="Bunaithe ar foirm neamhchaighdeÃ¡nach de /tharlÃº/">
<E offset="24" fromy="8" fromx="24" toy="8" tox="28" sentence="SÃ­lim nÃ¡rbh ea, agus is docha nach bhfuil i gceist ach easpa smaoinimh." errortext="docha" msg="An raibh /dÃ³cha/ ar intinn agat?">
<E offset="87" fromy="9" fromx="87" toy="9" tox="91" sentence="TÃ¡ sÃºil le feabhas nuair a thosÃ³idh airgead ag teacht isteach Ã³ ola agus gÃ¡s i mBearna Timor." errortext="Timor" msg="An raibh /TÃ­omÃ³r/ ar intinn agat?">
<E offset="66" fromy="10" fromx="66" toy="10" tox="78" sentence="Beidh nuachtÃ¡in shuaracha i ngreim cÃ© nach mbeadh cinsireacht den droch-chinÃ©al i gceist." errortext="droch-chinÃ©al" msg="Bunaithe ar focal mÃ­litrithe go coitianta /chinÃ©al (chineÃ¡l)/?">
<E offset="43" fromy="11" fromx="43" toy="11" tox="52" sentence="BhÃ­ sÃ© pÃ¡irteach sa chÃ©ad lÃ©iriÃº poiblÃ­ de Riverdance." errortext="Riverdance" msg="Is fÃ©idir gur focal iasachta Ã© seo (tÃ¡ na litreacha /Riv/ neamhdhÃ³chÃºil)">
<E offset="74" fromy="12" fromx="74" toy="12" tox="86" sentence="Beidh an tionchar le mothÃº nÃ­os mÃ³ i gcÃ¡s comhlachtaÃ­ Ã‰ireannacha mar gur mionairgeadra Ã© an punt." errortext="mionairgeadra" msg="Focal anaithnid ach is fÃ©idir gur comhfhocal /mion+airgeadra/ Ã©?">
<E offset="13" fromy="13" fromx="13" toy="13" tox="21" sentence="BhÃ­ an dream dÃ­-armtha ag iarraidh a gcuid gunnaÃ­." errortext="dÃ­-armtha" msg="Focal anaithnid ach is fÃ©idir gur comhfhocal neamhchaighdeÃ¡nach /dÃ­+armtha/ Ã©?">
<E offset="10" fromy="14" fromx="10" toy="14" tox="12" sentence="An bhfuil ayn uachtar roeite agattt?" errortext="ayn" msg="Focal anaithnid /aon, ann, an/?">
<E offset="22" fromy="14" fromx="22" toy="14" tox="27" sentence="An bhfuil ayn uachtar roeite agattt?" errortext="roeite" msg="Focal anaithnid /reoite/?">
<E offset="29" fromy="14" fromx="29" toy="14" tox="34" sentence="An bhfuil ayn uachtar roeite agattt?" errortext="agattt" msg="Is fÃ©idir gur focal iasachta Ã© seo (tÃ¡ na litreacha /ttt/ neamhdhÃ³chÃºil)">
<E offset="9" fromy="15" fromx="9" toy="15" tox="12" sentence="BÃ­onn an geÃ¡l ag satailt ar an dubh." errortext="geÃ¡l" msg="Focal ceart ach an-neamhchoitianta">
<E offset="23" fromy="16" fromx="23" toy="16" tox="40" sentence="Ach bhÃ­ mÃ© ag leanÃºint ar aghaidh an t-am ar fad leis." errortext="ar aghaidh an t-am" msg="TÃ¡ gÃ¡ leis an leagan ginideach anseo">
<E offset="0" fromy="17" fromx="0" toy="17" tox="8" sentence="Nach holc an mhaise duit a bheith ag magadh." errortext="Nach holc" msg="RÃ©amhlitir /h/ gan ghÃ¡">
<E offset="0" fromy="18" fromx="0" toy="18" tox="6" sentence="Ba hiad na hamhrÃ¡in i dtosach ba chÃºis leis." errortext="Ba hiad" msg="RÃ©amhlitir /h/ gan ghÃ¡">
<E offset="10" fromy="19" fromx="10" toy="19" tox="17" sentence="Ba iad na trÃ­ hÃ¡it iad BostÃºn, Baile Ãtha Cliath agus Nua Eabhrac." errortext="trÃ­ hÃ¡it" msg="RÃ©amhlitir /h/ gan ghÃ¡">
<E offset="3" fromy="20" fromx="3" toy="20" tox="10" sentence="Sa dara alt, dÃ©an cur sÃ­os ar a bhfaca siad sa SpÃ¡inn." errortext="dara alt" msg="RÃ©amhlitir /h/ ar iarraidh">
<E offset="44" fromy="21" fromx="44" toy="21" tox="55" sentence="Oirfeadh sÃ­ol Ã¡itiÃºil nÃ­os fearr nÃ¡ an sÃ­ol a hÃºsÃ¡idtear go minic." errortext="a hÃºsÃ¡idtear" msg="RÃ©amhlitir /h/ gan ghÃ¡">
<E offset="44" fromy="22" fromx="44" toy="22" tox="54" sentence="TÃ¡ ceacht stairiÃºil uathÃºil do chuairteoirÃ­ san t-ionad seo." errortext="san t-ionad" msg="RÃ©amhlitir /t/ gan ghÃ¡">
<E offset="3" fromy="23" fromx="3" toy="23" tox="19" sentence="In Ã‰irinn chaitheann breis is 30 faoin gcÃ©ad de mhnÃ¡ toitÃ­nÃ­." errortext="Ã‰irinn chaitheann" msg="SÃ©imhiÃº gan ghÃ¡">
<E offset="74" fromy="24" fromx="74" toy="24" tox="94" sentence="TÃ¡ sÃ© riachtanach ar mhaithe le feidhmiÃº an phlean a bheidh ceaptha ag an eagraÃ­ocht ceannasach." errortext="eagraÃ­ocht ceannasach" msg="SÃ©imhiÃº ar iarraidh">
<E offset="6" fromy="25" fromx="6" toy="25" tox="24" sentence="TÃ¡ na lachain slachtmhara ar eitilt." errortext="lachain slachtmhara" msg="SÃ©imhiÃº ar iarraidh">
<E offset="52" fromy="26" fromx="52" toy="26" tox="60" sentence="TÃ¡ an Rialtas tar Ã©is Ã¡it na Gaeilge i saol na tÃ­re a ceistiÃº." errortext="a ceistiÃº" msg="SÃ©imhiÃº ar iarraidh">
<E offset="53" fromy="27" fromx="53" toy="27" tox="60" sentence="BhÃ­odar ag rÃ¡ ar an aonach gur agamsa a bhÃ­ na huain ab fearr." errortext="ab fearr" msg="SÃ©imhiÃº ar iarraidh">
<E offset="10" fromy="28" fromx="10" toy="28" tox="22" sentence="NÃ­ bheidh ach mhallacht i ndÃ¡n dÃ³ Ã³ na cinÃ­ocha agus fuath Ã³ na nÃ¡isiÃºin." errortext="ach mhallacht" msg="SÃ©imhiÃº gan ghÃ¡">
<E offset="29" fromy="29" fromx="29" toy="29" tox="40" sentence="An bhfuil aon uachtar reoite ar an cuntar?" errortext="ar an cuntar" msg="UrÃº nÃ³ sÃ©imhiÃº ar iarraidh">
<E offset="14" fromy="30" fromx="14" toy="30" tox="21" sentence="MÃ¡ shuÃ­onn tÃº ag bhord le flaith, tabhair faoi deara go cÃºramach cÃ©ard atÃ¡ leagtha romhat." errortext="ag bhord" msg="SÃ©imhiÃº gan ghÃ¡">
<E offset="14" fromy="31" fromx="14" toy="31" tox="26" sentence="BlÃ¡thaÃ­onn sÃ© amhail bhlÃ¡th an mhachaire." errortext="amhail bhlÃ¡th" msg="SÃ©imhiÃº gan ghÃ¡">
<E offset="0" fromy="32" fromx="0" toy="32" tox="8" sentence="An bainim sult as bÃ¡s an drochdhuine?" errortext="An bainim" msg="UrÃº ar iarraidh">
<E offset="3" fromy="33" fromx="3" toy="33" tox="21" sentence="NÃ­ fÃ©idir an Gaeltacht a choinneÃ¡il mar rÃ©igiÃºn Gaeilge go nÃ¡isiÃºnta gan athrÃº bunÃºsach." errortext="fÃ©idir an Gaeltacht" msg="SÃ©imhiÃº ar iarraidh">
<E offset="22" fromy="34" fromx="22" toy="34" tox="37" sentence="Cad Ã© an chomhairle a thug an ochtapas dÃ³?" errortext="thug an ochtapas" msg="RÃ©amhlitir /t/ ar iarraidh">
<E offset="55" fromy="35" fromx="55" toy="35" tox="67" sentence="ChÃ³irigh sÃ© na lampaÃ­ le solas a chaitheamh os comhair an coinnleora." errortext="an coinnleora" msg="SÃ©imhiÃº ar iarraidh">
<E offset="34" fromy="36" fromx="34" toy="36" tox="46" sentence="ComhlÃ¡nÃ³idh saorÃ¡nacht an Aontais an saorÃ¡nacht nÃ¡isiÃºnta agus nÃ­ ghabhfaidh sÃ­ a hionad." errortext="an saorÃ¡nacht" msg="RÃ©amhlitir /t/ ar iarraidh">
<E offset="49" fromy="37" fromx="49" toy="37" tox="59" sentence="BÃ­onn na cimÃ­ ar a suaimhneas le chÃ©ile gan guth an sÃ©ilÃ©ara le clos a thuilleadh." errortext="an sÃ©ilÃ©ara" msg="RÃ©amhlitir /t/ ar iarraidh">
<E offset="40" fromy="38" fromx="40" toy="38" tox="46" sentence="TÃ¡ sin rÃ¡ite cheana fÃ©in acu le muintir an tÃ­re seo." errortext="an tÃ­re" msg="Ba chÃ³ir duit /na/ a ÃºsÃ¡id anseo">
<E offset="68" fromy="39" fromx="68" toy="39" tox="81" sentence="Is Ã© is dÃ³ichÃ­ go raibh baint ag an eisimirce leis an laghdÃº i lÃ­on an gcainteoirÃ­ Gaeilge." errortext="an gcainteoirÃ­" msg="Ba chÃ³ir duit /na/ a ÃºsÃ¡id anseo">
<E offset="5" fromy="40" fromx="5" toy="40" tox="24" sentence="Ba Ã© an fear an phortaigh a thÃ¡inig thart leis na plÃ¡taÃ­ bia." errortext="an fear an phortaigh" msg="NÃ­ gÃ¡ leis an alt cinnte anseo">
<E offset="20" fromy="41" fromx="20" toy="41" tox="44" sentence="TÃ¡ dhÃ¡ shiombail ag an bharr gach leathanaigh." errortext="an bharr gach leathanaigh" msg="NÃ­ gÃ¡ leis an alt cinnte anseo">
<E offset="10" fromy="42" fromx="10" toy="42" tox="22" sentence="NÃ­ bheidh aon buntÃ¡iste againn orthu sin." errortext="aon buntÃ¡iste" msg="SÃ©imhiÃº ar iarraidh">
<E offset="0" fromy="43" fromx="0" toy="43" tox="8" sentence="Ar gcaith tÃº do chiall agus do chÃ©adfaÃ­ ar fad?" errortext="Ar gcaith" msg="SÃ©imhiÃº ar iarraidh">
<E offset="10" fromy="44" fromx="10" toy="44" tox="21" sentence="NÃ­ amhÃ¡in Ã¡r dhÃ¡ chosa, ach nigh Ã¡r lÃ¡mha!" errortext="Ã¡r dhÃ¡ chosa" msg="UrÃº ar iarraidh">
<E offset="48" fromy="45" fromx="48" toy="45" tox="55" sentence="Gheobhaimid maoin de gach sÃ³rt, agus lÃ­onfaimid Ã¡r tithe le creach." errortext="Ã¡r tithe" msg="UrÃº ar iarraidh">
<E offset="11" fromy="46" fromx="11" toy="46" tox="18" sentence="NÃ­l aon nÃ­ arbh fiÃº a shantÃº seachas Ã­." errortext="arbh fiÃº" msg="SÃ©imhiÃº ar iarraidh">
<E offset="0" fromy="47" fromx="0" toy="47" tox="7" sentence="Ba maith liom fios a thabhairt anois daoibh." errortext="Ba maith" msg="SÃ©imhiÃº ar iarraidh">
<E offset="0" fromy="48" fromx="0" toy="48" tox="5" sentence="Ba eol duit go hiomlÃ¡n m'anam." errortext="Ba eol" msg="Ba chÃ³ir duit /b+uaschamÃ³g/ a ÃºsÃ¡id anseo">
<E offset="7" fromy="49" fromx="7" toy="49" tox="21" sentence="D'fhan beirt buachaill sa champa." errortext="beirt buachaill" msg="SÃ©imhiÃº ar iarraidh">
<E offset="7" fromy="50" fromx="7" toy="50" tox="31" sentence="D'fhan beirt bhuachaill cancrach sa champa." errortext="beirt bhuachaill cancrach" msg="SÃ©imhiÃº ar iarraidh">
<E offset="10" fromy="51" fromx="10" toy="51" tox="23" sentence="NÃ­ amhÃ¡in bhur dhÃ¡ chosa, ach nigh bhur lÃ¡mha!" errortext="bhur dhÃ¡ chosa" msg="UrÃº ar iarraidh">
<E offset="28" fromy="52" fromx="28" toy="52" tox="40" sentence="DÃ©anaigÃ­ beart leis de rÃ©ir bhur briathra." errortext="bhur briathra" msg="UrÃº ar iarraidh">
<E offset="0" fromy="53" fromx="0" toy="53" tox="10" sentence="CÃ¡ cuireann tÃº do thrÃ©ad ar fÃ©arach?" errortext="CÃ¡ cuireann" msg="UrÃº ar iarraidh">
<E offset="0" fromy="54" fromx="0" toy="54" tox="5" sentence="CÃ¡ Ã¡it a nochtfadh sÃ© Ã© fÃ©in ach i mBostÃºn!" errortext="CÃ¡ Ã¡it" msg="RÃ©amhlitir /h/ ar iarraidh">
<E offset="0" fromy="55" fromx="0" toy="55" tox="6" sentence="CÃ¡ chÃ¡s dÃºinn bheith ag mÃ¡inneÃ¡il thart anseo?" errortext="CÃ¡ chÃ¡s" msg="SÃ©imhiÃº gan ghÃ¡">
<E offset="0" fromy="56" fromx="0" toy="56" tox="6" sentence="CÃ¡r fÃ¡g tÃº eisean?" errortext="CÃ¡r fÃ¡g" msg="Ba chÃ³ir duit /cÃ¡/ a ÃºsÃ¡id anseo">
<E offset="0" fromy="57" fromx="0" toy="57" tox="8" sentence="CÃ¡r bhfÃ¡g tÃº eisean?" errortext="CÃ¡r bhfÃ¡g" msg="SÃ©imhiÃº ar iarraidh">
<E offset="19" fromy="58" fromx="19" toy="58" tox="20" sentence="CÃ¡r fÃ¡gadh eisean (OK)?" errortext="OK" msg="Is fÃ©idir gur focal iasachta Ã© seo (tÃ¡ na litreacha /^OK/ neamhdhÃ³chÃºil)">
<E offset="0" fromy="59" fromx="0" toy="59" tox="5" sentence="CÃ© iad na fir seo ag fanacht farat?" errortext="CÃ© iad" msg="RÃ©amhlitir /h/ ar iarraidh">
<E offset="0" fromy="60" fromx="0" toy="60" tox="4" sentence="CÃ© an ceart atÃ¡ agamsa a thuilleadh fÃ³s a lorg ar an rÃ­?" errortext="CÃ© an" msg="Ba chÃ³ir duit /cÃ©n/ a ÃºsÃ¡id anseo">
<E offset="15" fromy="61" fromx="15" toy="61" tox="29" sentence="D'fhoilsigh sÃ­ a cÃ©ad cnuasach filÃ­ochta i 1995." errortext="a cÃ©ad cnuasach" msg="SÃ©imhiÃº ar iarraidh">
<E offset="20" fromy="62" fromx="20" toy="62" tox="32" sentence="Chuir siad fios orm ceithre uaire ar an tslÃ­ sin." errortext="ceithre uaire" msg="Ba chÃ³ir duit /huaire/ a ÃºsÃ¡id anseo">
<E offset="48" fromy="63" fromx="48" toy="63" tox="59" sentence="Beidh ar Bhord FeidhmiÃºchÃ¡in an tUachtarÃ¡n agus ceithre ball eile." errortext="ceithre ball" msg="SÃ©imhiÃº ar iarraidh">
<E offset="0" fromy="64" fromx="0" toy="64" tox="11" sentence="CÃ©n amhrÃ¡naÃ­ is fearr leat?" errortext="CÃ©n amhrÃ¡naÃ­" msg="RÃ©amhlitir /t/ ar iarraidh">
<E offset="7" fromy="65" fromx="7" toy="65" tox="20" sentence="BhÃ­ an chÃ©ad cruinniÃº den ChoimisiÃºn i Ros Muc i nGaeltacht na Gaillimhe." errortext="chÃ©ad cruinniÃº" msg="SÃ©imhiÃº ar iarraidh">
<E offset="6" fromy="66" fromx="6" toy="66" tox="18" sentence="TÃ¡ sÃ© chomh iontach le sneachta dearg." errortext="chomh iontach" msg="RÃ©amhlitir /h/ ar iarraidh">
<E offset="20" fromy="67" fromx="20" toy="67" tox="36" sentence="Chuir mÃ© cÃ©ad punta chuig an banaltra." errortext="chuig an banaltra" msg="UrÃº nÃ³ sÃ©imhiÃº ar iarraidh">
<E offset="22" fromy="68" fromx="22" toy="68" tox="34" sentence="NÃ­l tÃº do do sheoladh chuig dhaoine a labhraÃ­onn teanga dhothuigthe." errortext="chuig dhaoine" msg="SÃ©imhiÃº gan ghÃ¡">
<E offset="30" fromy="69" fromx="30" toy="69" tox="41" sentence="BhÃ­ sÃ© cÃºig bhanlÃ¡mh ar fhad, cÃºig banlÃ¡mh ar leithead." errortext="cÃºig banlÃ¡mh" msg="SÃ©imhiÃº ar iarraidh">
<E offset="18" fromy="70" fromx="18" toy="70" tox="29" sentence="Beirim mo mhionna dar an beart a rinne Dia le mo shinsir." errortext="dar an beart" msg="UrÃº nÃ³ sÃ©imhiÃº ar iarraidh">
<E offset="12" fromy="71" fromx="12" toy="71" tox="23" sentence="DearbhaÃ­m Ã© dar chuthach m'Ã©ada i gcoinne na gcinÃ­ocha eile." errortext="dar chuthach" msg="SÃ©imhiÃº gan ghÃ¡">
<E offset="20" fromy="72" fromx="20" toy="72" tox="35" sentence="Sa dara bliain dÃ©ag dÃ¡r braighdeanas, thÃ¡inig fear ar a theitheadh." errortext="dÃ¡r braighdeanas" msg="UrÃº ar iarraidh">
<E offset="25" fromy="73" fromx="25" toy="73" tox="32" sentence="D'oibrigh mÃ© liom go dtÃ­ DÃ© Aoine." errortext="DÃ© Aoine" msg="RÃ©amhlitir /h/ ar iarraidh">
<E offset="4" fromy="74" fromx="4" toy="74" tox="14" sentence="BhÃ­ deich tobar fÃ­oruisce agus seachtÃ³ crann pailme ann." errortext="deich tobar" msg="UrÃº ar iarraidh">
<E offset="12" fromy="75" fromx="12" toy="75" tox="24" sentence="TÃ³gfaidh mÃ© do coinnleoir Ã³na ionad, mura ndÃ©ana tÃº aithrÃ­." errortext="do coinnleoir" msg="SÃ©imhiÃº ar iarraidh">
<E offset="13" fromy="76" fromx="13" toy="76" tox="21" sentence="Is cÃºis imnÃ­ don pobal a laghad maoinithe a dhÃ©antar ar NaÃ­scoileanna." errortext="don pobal" msg="SÃ©imhiÃº ar iarraidh">
<E offset="22" fromy="77" fromx="22" toy="77" tox="26" sentence="Creidim go raibh siad de an thuairim chÃ©anna." errortext="de an" msg="Ba chÃ³ir duit /den/ a ÃºsÃ¡id anseo">
<E offset="0" fromy="78" fromx="0" toy="78" tox="12" sentence="TÃ¡ dhÃ¡ teanga oifigiÃºla le stÃ¡das bunreachtÃºil Ã¡ labhairt sa tÃ­r seo." errortext="TÃ¡ dhÃ¡ teanga" msg="SÃ©imhiÃº ar iarraidh">
<E offset="43" fromy="79" fromx="43" toy="79" tox="47" sentence="CÃ¡ bhfuil feoil le fÃ¡il agamsa le tabhairt do an mhuintir seo?" errortext="do an" msg="Ba chÃ³ir duit /don/ a ÃºsÃ¡id anseo">
<E offset="44" fromy="80" fromx="44" toy="80" tox="56" sentence="Is amhlaidh a bheidh freisin do na tagairtÃ­ do airteagail." errortext="do airteagail" msg="Ba chÃ³ir duit /d+uaschamÃ³g/ a ÃºsÃ¡id anseo">
<E offset="40" fromy="81" fromx="40" toy="81" tox="43" sentence="TÃ¡ sÃ© de chÃºram seirbhÃ­s a chur ar fÃ¡il do a gcustaimÃ©irÃ­ i nGaeilge." errortext="do a" msg="Ba chÃ³ir duit /dÃ¡/ a ÃºsÃ¡id anseo">
<E offset="29" fromy="82" fromx="29" toy="82" tox="33" sentence="SeinnigÃ­ moladh ar an gcruit do Ã¡r nDia." errortext="do Ã¡r" msg="Ba chÃ³ir duit /dÃ¡r/ a ÃºsÃ¡id anseo">
<E offset="55" fromy="83" fromx="55" toy="83" tox="61" sentence="Tabharfaidh an tUachtarÃ¡n a Ã³rÃ¡id ag leath i ndiaidh a dÃ³ dÃ©ag DÃ© Sathairn." errortext="dÃ³ dÃ©ag" msg="SÃ©imhiÃº ar iarraidh">
<E offset="21" fromy="84" fromx="21" toy="84" tox="35" sentence="TÃ¡ an domhan go lÃ©ir faoi suaimhneas." errortext="faoi suaimhneas" msg="SÃ©imhiÃº ar iarraidh">
<E offset="59" fromy="85" fromx="59" toy="85" tox="65" sentence="Caithfidh pobal na Gaeltachta iad fÃ©in cinneadh a dhÃ©anamh faoi an Ghaeilge." errortext="faoi an" msg="Ba chÃ³ir duit /faoin/ a ÃºsÃ¡id anseo">
<E offset="31" fromy="86" fromx="31" toy="86" tox="36" sentence="Cuireann sÃ­ a neart mar chrios faoi a coim." errortext="faoi a" msg="Ba chÃ³ir duit /faoina/ a ÃºsÃ¡id anseo">
<E offset="21" fromy="87" fromx="21" toy="87" tox="27" sentence="Cuireann sÃ© cinÃ­ocha faoi Ã¡r smacht agus cuireann sÃ© nÃ¡isiÃºin faoinÃ¡r gcosa." errortext="faoi Ã¡r" msg="Ba chÃ³ir duit /faoinÃ¡r/ a ÃºsÃ¡id anseo">
<E offset="41" fromy="88" fromx="41" toy="88" tox="51" sentence="TÃ¡ dualgas ar an gComhairle sin tabhairt faoin cÃºram seo." errortext="faoin cÃºram" msg="UrÃº nÃ³ sÃ©imhiÃº ar iarraidh">
<E offset="56" fromy="89" fromx="56" toy="89" tox="68" sentence="NÃ­ bheidh gearÃ¡n ag duine ar bith faoin gciste fial atÃ¡ faoinÃ¡r cÃºram." errortext="faoinÃ¡r cÃºram" msg="UrÃº ar iarraidh">
<E offset="16" fromy="90" fromx="16" toy="90" tox="30" sentence="Beidh parÃ¡id LÃ¡ FhÃ©ile PhÃ¡draig i mBostÃºn." errortext="FhÃ©ile PhÃ¡draig" msg="SÃ©imhiÃº gan ghÃ¡">
<E offset="62" fromy="91" fromx="62" toy="91" tox="63" sentence="TÃ¡ FÃ©ile Bhealtaine an Oireachtais ar siÃºl an tseachtain seo (OK)." errortext="OK" msg="Is fÃ©idir gur focal iasachta Ã© seo (tÃ¡ na litreacha /^OK/ neamhdhÃ³chÃºil)">
<E offset="47" fromy="92" fromx="47" toy="92" tox="57" sentence="TÃ¡ ar chumas an duine saol iomlÃ¡n a chaitheamh gan theanga eile Ã¡ brÃº air." errortext="gan theanga" msg="SÃ©imhiÃº gan ghÃ¡">
<E offset="19" fromy="93" fromx="19" toy="93" tox="30" sentence="TÃ¡ gruaim mhÃ³r orm gan ChaitlÃ­n." errortext="gan ChaitlÃ­n" msg="SÃ©imhiÃº gan ghÃ¡">
<E offset="67" fromy="94" fromx="67" toy="94" tox="78" sentence="Is stÃ¡it ilteangacha iad cuid mhÃ³r de na stÃ¡it sin atÃ¡ aonteangach go oifigiÃºil." errortext="go oifigiÃºil" msg="RÃ©amhlitir /h/ ar iarraidh">
<E offset="30" fromy="95" fromx="30" toy="95" tox="37" sentence="NÃ­ bheidh bonn comparÃ¡ide ann go beidh torthaÃ­ DhaonÃ¡ireamh 2007 ar fÃ¡il." errortext="go beidh" msg="UrÃº ar iarraidh">
<E offset="17" fromy="96" fromx="17" toy="96" tox="25" sentence="Rug sÃ© ar ais mÃ© go dhoras an Teampaill." errortext="go dhoras" msg="SÃ©imhiÃº gan ghÃ¡">
<E offset="16" fromy="97" fromx="16" toy="97" tox="20" sentence="Chuaigh mÃ© suas go an doras cÃºil a chaisleÃ¡in." errortext="go an" msg="Ba chÃ³ir duit /go dtÃ­/ a ÃºsÃ¡id anseo">
<E offset="12" fromy="98" fromx="12" toy="98" tox="23" sentence="Tar, tÃ©anam go dtÃ­ bhean na bhfÃ­seanna." errortext="go dtÃ­ bhean" msg="SÃ©imhiÃº gan ghÃ¡">
<E offset="15" fromy="99" fromx="15" toy="99" tox="26" sentence="Ba mhaith liom gur bhfÃ¡gann daoine Ã³ga an scoil agus iad ullmhaithe." errortext="gur bhfÃ¡gann" msg="Ba chÃ³ir duit /go/ a ÃºsÃ¡id anseo">
<E offset="11" fromy="100" fromx="11" toy="100" tox="19" sentence="Bhraith mÃ© gur fuair mÃ© boladh trom tais uathu." errortext="gur fuair" msg="Ba chÃ³ir duit /go/ a ÃºsÃ¡id anseo">
<E offset="20" fromy="101" fromx="20" toy="101" tox="28" sentence="An ea nach cÃ¡s leat gur bhfÃ¡g mo dheirfiÃºr an freastal fÃºmsa i m'aonar?" errortext="gur bhfÃ¡g" msg="SÃ©imhiÃº ar iarraidh">
<E offset="10" fromy="102" fromx="10" toy="102" tox="20" sentence="B'fhÃ©idir gurbh fearr Ã© seo duit nÃ¡ leamhnacht na bÃ³ ba mhilse i gcontae Chill MhantÃ¡in." errortext="gurbh fearr" msg="SÃ©imhiÃº ar iarraidh">
<E offset="34" fromy="103" fromx="34" toy="103" tox="44" sentence="An bhfuil aon uachtar reoite agat i cuisneoir?" errortext="i cuisneoir" msg="UrÃº ar iarraidh">
<E offset="34" fromy="104" fromx="34" toy="104" tox="45" sentence="An bhfuil aon uachtar reoite agat i chuisneoir?" errortext="i chuisneoir" msg="UrÃº ar iarraidh">
<E offset="36" fromy="105" fromx="36" toy="105" tox="41" sentence="An bhfuil aon uachtar reoite agaibh i bhur gcuisneoir?" errortext="i bhur" msg="Ba chÃ³ir duit /in bhur/ a ÃºsÃ¡id anseo">
<E offset="34" fromy="106" fromx="34" toy="106" tox="38" sentence="An bhfuil aon uachtar reoite agat i dhÃ¡ chuisneoir?" errortext="i dhÃ¡" msg="Ba chÃ³ir duit /in dhÃ¡/ a ÃºsÃ¡id anseo">
<E offset="34" fromy="107" fromx="34" toy="107" tox="37" sentence="An bhfuil aon uachtar reoite agat i an chuisneoir?" errortext="i an" msg="Ba chÃ³ir duit /sa/ a ÃºsÃ¡id anseo">
<E offset="34" fromy="108" fromx="34" toy="108" tox="37" sentence="An bhfuil aon uachtar reoite agat i na cuisneoirÃ­?" errortext="i na" msg="Ba chÃ³ir duit /sna/ a ÃºsÃ¡id anseo">
<E offset="29" fromy="109" fromx="29" toy="109" tox="31" sentence="An bhfuil aon uachtar reoite i a cuisneoir?" errortext="i a" msg="Ba chÃ³ir duit /ina/ a ÃºsÃ¡id anseo">
<E offset="36" fromy="110" fromx="36" toy="110" tox="39" sentence="Rinne gach cine Ã© sin sna cathracha i ar lonnaÃ­odar." errortext="i ar" msg="Ba chÃ³ir duit /inar/ a ÃºsÃ¡id anseo">
<E offset="29" fromy="111" fromx="29" toy="111" tox="32" sentence="An bhfuil aon uachtar reoite i Ã¡r gcuisneoir?" errortext="i Ã¡r" msg="Ba chÃ³ir duit /inÃ¡r/ a ÃºsÃ¡id anseo">
<E offset="30" fromy="112" fromx="30" toy="112" tox="34" sentence="Thug sÃ© seo deis dom breathnÃº in mo thimpeall." errortext="in mo" msg="Ba chÃ³ir duit /i/ a ÃºsÃ¡id anseo">
<E offset="12" fromy="113" fromx="12" toy="113" tox="25" sentence="TÃ¡ beirfean inÃ¡r craiceann faoi mar a bheimis i sorn." errortext="inÃ¡r craiceann" msg="UrÃº ar iarraidh">
<E offset="51" fromy="114" fromx="51" toy="114" tox="61" sentence="Is tuar dÃ³chais Ã© an mÃ©id dul chun cinn atÃ¡ dÃ©anta le bhlianta beaga." errortext="le bhlianta" msg="SÃ©imhiÃº gan ghÃ¡">
<E offset="39" fromy="115" fromx="39" toy="115" tox="43" sentence="D'fhÃ©adfadh tÃ¡bhacht a bheith ag baint le an gcÃ©ad toisc dÃ­obh sin." errortext="le an" msg="Ba chÃ³ir duit /leis an/ a ÃºsÃ¡id anseo">
<E offset="50" fromy="116" fromx="50" toy="116" tox="54" sentence="Molann an CoimisiÃºn go maoineofaÃ­ scÃ©im chun tacÃº le na pobail sin." errortext="le na" msg="Ba chÃ³ir duit /leis na/ a ÃºsÃ¡id anseo">
<E offset="34" fromy="117" fromx="34" toy="117" tox="37" sentence="LabhraÃ­odh gach duine an fhÃ­rinne le a chomharsa." errortext="le a" msg="Ba chÃ³ir duit /lena/ a ÃºsÃ¡id anseo">
<E offset="28" fromy="118" fromx="28" toy="118" tox="32" sentence="Beir i do lÃ¡imh ar an tslat le ar bhuail tÃº an abhainn, agus seo leat." errortext="le ar" msg="Ba chÃ³ir duit /lenar/ a ÃºsÃ¡id anseo">
<E offset="35" fromy="119" fromx="35" toy="119" tox="39" sentence="Ba mhaith liom buÃ­ochas a ghlacadh le Ã¡r bhfoireann riarachÃ¡in." errortext="le Ã¡r" msg="Ba chÃ³ir duit /lenÃ¡r/ a ÃºsÃ¡id anseo">
<E offset="20" fromy="120" fromx="20" toy="120" tox="25" sentence="TÃ³gann siad cuid de le iad fÃ©in a thÃ©amh." errortext="le iad" msg="RÃ©amhlitir /h/ ar iarraidh">
<E offset="27" fromy="121" fromx="27" toy="121" tox="42" sentence="TÃ¡ do scrios chomh leathan leis an farraige." errortext="leis an farraige" msg="UrÃº nÃ³ sÃ©imhiÃº ar iarraidh">
<E offset="26" fromy="122" fromx="26" toy="122" tox="36" sentence="Is linne Ã­ ar ndÃ³igh agus lenÃ¡r clann." errortext="lenÃ¡r clann" msg="UrÃº ar iarraidh">
<E offset="0" fromy="123" fromx="0" toy="123" tox="8" sentence="MÃ¡ tugann rÃ­ breith ar na boicht le cothromas, bunÃ³far a rÃ­chathaoir go brÃ¡ch." errortext="MÃ¡ tugann" msg="SÃ©imhiÃº ar iarraidh">
<E offset="28" fromy="124" fromx="28" toy="124" tox="37" sentence="RoghnaÃ­tear an bhliain 1961 mar pointe tosaigh don anailÃ­s." errortext="mar pointe" msg="SÃ©imhiÃº ar iarraidh">
<E offset="9" fromy="125" fromx="9" toy="125" tox="20" sentence="ComhlÃ­on mo aitheanta agus mairfidh tÃº beo." errortext="mo aitheanta" msg="Ba chÃ³ir duit /m+uaschamÃ³g/ a ÃºsÃ¡id anseo">
<E offset="15" fromy="126" fromx="15" toy="126" tox="26" sentence="Ceapadh mise i mo bolscaire." errortext="mo bolscaire" msg="SÃ©imhiÃº ar iarraidh">
<E offset="34" fromy="127" fromx="34" toy="127" tox="45" sentence="TÃ¡ mÃ© ag sclÃ¡bhaÃ­ocht ag iarraidh mo dhÃ¡ gasÃºr a chur trÃ­ scoil." errortext="mo dhÃ¡ gasÃºr" msg="SÃ©imhiÃº ar iarraidh">
<E offset="0" fromy="128" fromx="0" toy="128" tox="10" sentence="Mura tagann aon duine i gcabhair orainn, rachaimid anonn chugaibh." errortext="Mura tagann" msg="UrÃº ar iarraidh">
<E offset="0" fromy="129" fromx="0" toy="129" tox="17" sentence="Murar chruthaÃ­tear lÃ¡ agus oÃ­che... teilgim uaim sliocht IacÃ³ib." errortext="Murar chruthaÃ­tear" msg="SÃ©imhiÃº gan ghÃ¡">
<E offset="0" fromy="130" fromx="0" toy="130" tox="15" sentence="Murar gcruthaigh mise lÃ¡ agus oÃ­che... teilgim uaim sliocht IacÃ³ib." errortext="Murar gcruthaigh" msg="SÃ©imhiÃº ar iarraidh">
<E offset="37" fromy="131" fromx="37" toy="131" tox="42" sentence="An bhfuil aon uachtar reoite ag fear na bÃ¡d?" errortext="na bÃ¡d" msg="UrÃº ar iarraidh">
<E offset="18" fromy="132" fromx="18" toy="132" tox="27" sentence="Is mÃ³r ag nÃ¡isiÃºn na Ã‰ireann a choibhneas speisialta le daoine de bhunadh na hÃ‰ireann atÃ¡ ina gcÃ³naÃ­ ar an gcoigrÃ­och." errortext="na Ã‰ireann" msg="RÃ©amhlitir /h/ ar iarraidh">
<E offset="44" fromy="133" fromx="44" toy="133" tox="58" sentence="Chuir an CoimisiÃºn fÃ©in comhfhreagras chuig na eagraÃ­ochtaÃ­ seo ag lorg eolais faoina ngnÃ­omhaÃ­ochtaÃ­." errortext="na eagraÃ­ochtaÃ­" msg="RÃ©amhlitir /h/ ar iarraidh">
<E offset="0" fromy="134" fromx="0" toy="134" tox="10" sentence="NÃ¡ iompaÃ­gÃ­ chun na n-Ã­ol, agus nÃ¡ dealbhaÃ­gÃ­ dÃ©ithe de mhiotal." errortext="NÃ¡ iompaÃ­gÃ­" msg="RÃ©amhlitir /h/ ar iarraidh">
<E offset="43" fromy="135" fromx="43" toy="135" tox="50" sentence="Is fearr de bhÃ©ile luibheanna agus grÃ¡ leo nÃ¡ mhart mÃ©ith agus grÃ¡in leis." errortext="nÃ¡ mhart" msg="SÃ©imhiÃº gan ghÃ¡">
<E offset="0" fromy="136" fromx="0" toy="136" tox="12" sentence="Nach bainfidh mÃ© uaidh an mÃ©id a ghoid sÃ© uaim?" errortext="Nach bainfidh" msg="UrÃº ar iarraidh">
<E offset="23" fromy="137" fromx="23" toy="137" tox="33" sentence="Rinneadh an roinnt don naoi treibh go leith ar cranna." errortext="naoi treibh" msg="UrÃº ar iarraidh">
<E offset="44" fromy="138" fromx="44" toy="138" tox="57" sentence="ThÃ¡inig na brÃ³ga chomh fada siar le haimsir Naomh PhÃ¡draig fÃ©in." errortext="Naomh PhÃ¡draig" msg="SÃ©imhiÃº gan ghÃ¡">
<E offset="0" fromy="139" fromx="0" toy="139" tox="7" sentence="NÃ¡r breÃ¡ liom claÃ­omh a bheith agam i mo ghlac!" errortext="NÃ¡r breÃ¡" msg="SÃ©imhiÃº ar iarraidh">
<E offset="0" fromy="140" fromx="0" toy="140" tox="13" sentence="NÃ¡r bhfreagair sÃ© thÃº, focal ar fhocal." errortext="NÃ¡r bhfreagair" msg="SÃ©imhiÃº ar iarraidh">
<E offset="43" fromy="141" fromx="43" toy="141" tox="54" sentence="Feicimid gur de dheasca a n-easumhlaÃ­ochta nÃ¡rbh fÃ©idir leo dul isteach ann." errortext="nÃ¡rbh fÃ©idir" msg="SÃ©imhiÃº ar iarraidh">
<E offset="0" fromy="142" fromx="0" toy="142" tox="11" sentence="NÃ­ fÃ©adfaidh a gcuid airgid nÃ¡ Ã³ir iad a shÃ¡bhÃ¡il." errortext="NÃ­ fÃ©adfaidh" msg="SÃ©imhiÃº ar iarraidh">
<E offset="0" fromy="143" fromx="0" toy="143" tox="5" sentence="NÃ­ iad sin do phÃ­opaÃ­ ar an tÃ¡bla!" errortext="NÃ­ iad" msg="RÃ©amhlitir /h/ ar iarraidh">
<E offset="23" fromy="144" fromx="23" toy="144" tox="36" sentence="BhÃ­ an mÃ©id sin airgid nÃ­ba luachmhar dÃºinn nÃ¡ maoin an domhain." errortext="nÃ­ba luachmhar" msg="Ba chÃ³ir duit an bhreischÃ©im a ÃºsÃ¡id anseo">
<E offset="14" fromy="145" fromx="14" toy="145" tox="20" sentence="Eisean beagÃ¡n nÃ­b Ã³ga nÃ¡ mise." errortext="nÃ­b Ã³ga" msg="Ba chÃ³ir duit an bhreischÃ©im a ÃºsÃ¡id anseo">
<E offset="14" fromy="146" fromx="14" toy="146" tox="22" sentence="Eisean beagÃ¡n nÃ­ba Ã³ige nÃ¡ mise." errortext="nÃ­ba Ã³ige" msg="Ba chÃ³ir duit /nÃ­b/ a ÃºsÃ¡id anseo">
<E offset="22" fromy="147" fromx="22" toy="147" tox="32" sentence="BhÃ­ na pÃ¡istÃ­ ag Ã©irÃ­ nÃ­ba trÃ©ine." errortext="nÃ­ba trÃ©ine" msg="SÃ©imhiÃº ar iarraidh">
<E offset="35" fromy="148" fromx="20" toy="148" tox="32" sentence="&quot;TÃ¡,&quot; ar sise, &quot;ach nÃ­or fhacthas Ã© sin.&quot;" errortext="nÃ­or fhacthas" msg="Ba chÃ³ir duit /nÃ­/ a ÃºsÃ¡id anseo">
<E offset="0" fromy="149" fromx="0" toy="149" tox="6" sentence="NÃ­or gÃ¡ do dheoraÃ­ riamh codladh sa tsrÃ¡id; BhÃ­ mo dhoras riamh ar leathadh." errortext="NÃ­or gÃ¡" msg="SÃ©imhiÃº ar iarraidh">
<E offset="35" fromy="150" fromx="20" toy="150" tox="29" sentence="&quot;TÃ¡,&quot; ar sise, &quot;ach nÃ­or fuair muid aon ocras fÃ³s." errortext="nÃ­or fuair" msg="Ba chÃ³ir duit /nÃ­/ a ÃºsÃ¡id anseo">
<E offset="0" fromy="151" fromx="0" toy="151" tox="9" sentence="NÃ­or mbain sÃ© leis an dream a bhÃ­ i gcogar ceilge." errortext="NÃ­or mbain" msg="SÃ©imhiÃº ar iarraidh">
<E offset="0" fromy="152" fromx="0" toy="152" tox="12" sentence="NÃ­orbh folÃ¡ir dÃ³ Ã©isteacht a thabhairt dom." errortext="NÃ­orbh folÃ¡ir" msg="SÃ©imhiÃº ar iarraidh">
<E offset="10" fromy="153" fromx="10" toy="153" tox="19" sentence="Ach anois Ã³ cuimhnÃ­m air, bhÃ­ ardÃ¡n coincrÃ©ite sa phÃ¡irc." errortext="Ã³ cuimhnÃ­m" msg="SÃ©imhiÃº ar iarraidh">
<E offset="29" fromy="154" fromx="29" toy="154" tox="34" sentence="Tabhair an t-ordÃº seo leanas Ã³ bÃ©al." errortext="Ã³ bÃ©al" msg="SÃ©imhiÃº ar iarraidh">
<E offset="21" fromy="155" fromx="21" toy="155" tox="24" sentence="BÃ­odh bhur ngrÃ¡ saor Ã³ an gcur i gcÃ©ill." errortext="Ã³ an" msg="Ba chÃ³ir duit /Ã³n/ a ÃºsÃ¡id anseo">
<E offset="4" fromy="156" fromx="4" toy="156" tox="13" sentence="BhÃ­ ocht tÃ¡bla ar fad ar a maraÃ­dÃ­s na hÃ­obairtÃ­." errortext="ocht tÃ¡bla" msg="UrÃº ar iarraidh">
<E offset="21" fromy="157" fromx="21" toy="157" tox="26" sentence="BÃ­odh bhur ngrÃ¡ saor Ã³n cur i gcÃ©ill." errortext="Ã³n cur" msg="UrÃº nÃ³ sÃ©imhiÃº ar iarraidh">
<E offset="13" fromy="158" fromx="13" toy="158" tox="15" sentence="Amharcann sÃ© Ã³ a ionad cÃ³naithe ar gach aon neach dÃ¡ maireann ar talamh." errortext="Ã³ a" msg="Ba chÃ³ir duit /Ã³na/ a ÃºsÃ¡id anseo">
<E offset="43" fromy="159" fromx="43" toy="159" tox="46" sentence="Seo iad a gcÃ©imeanna de rÃ©ir na n-Ã¡iteanna Ã³ ar thosaÃ­odar." errortext="Ã³ ar" msg="Ba chÃ³ir duit /Ã³nar/ a ÃºsÃ¡id anseo">
<E offset="29" fromy="160" fromx="29" toy="160" tox="32" sentence="Agus rinne sÃ© Ã¡r bhfuascailt Ã³ Ã¡r naimhde." errortext="Ã³ Ã¡r" msg="Ba chÃ³ir duit /Ã³nÃ¡r/ a ÃºsÃ¡id anseo">
<E offset="28" fromy="161" fromx="28" toy="161" tox="36" sentence="BhÃ­odh sÃºil in airde againn Ã³nÃ¡r tÃºir faire." errortext="Ã³nÃ¡r tÃºir" msg="UrÃº ar iarraidh">
<E offset="44" fromy="162" fromx="44" toy="162" tox="55" sentence="TÃ¡ do ghÃ©aga sprÃ©ite ar bhraillÃ­n ghlÃ©igeal os fharraige faoileÃ¡n." errortext="os fharraige" msg="SÃ©imhiÃº gan ghÃ¡">
<E offset="23" fromy="163" fromx="23" toy="163" tox="26" sentence="Uaidh fÃ©in, b'fhÃ©idir, pÃ© Ã© fÃ©in." errortext="pÃ© Ã©" msg="RÃ©amhlitir /h/ ar iarraidh">
<E offset="23" fromy="164" fromx="23" toy="164" tox="36" sentence="Agus thÃ¡inig scÃ©in air roimh an pobal seo ar a lÃ­onmhaire." errortext="roimh an pobal" msg="UrÃº nÃ³ sÃ©imhiÃº ar iarraidh">
<E offset="18" fromy="165" fromx="18" toy="165" tox="29" sentence="Is gaiste Ã© eagla roimh daoine." errortext="roimh daoine" msg="SÃ©imhiÃº ar iarraidh">
<E offset="34" fromy="166" fromx="34" toy="166" tox="45" sentence="An bhfuil aon uachtar reoite agat sa cuisneoir?" errortext="sa cuisneoir" msg="SÃ©imhiÃº ar iarraidh">
<E offset="34" fromy="167" fromx="34" toy="167" tox="43" sentence="An bhfuil aon uachtar reoite agat sa seamair?" errortext="sa seamair" msg="RÃ©amhlitir /t/ ar iarraidh">
<E offset="44" fromy="168" fromx="44" toy="168" tox="45" sentence="An bhfuil aon uachtar reoite agat sa scoil (OK)?" errortext="OK" msg="Is fÃ©idir gur focal iasachta Ã© seo (tÃ¡ na litreacha /^OK/ neamhdhÃ³chÃºil)">
<E offset="47" fromy="169" fromx="47" toy="169" tox="48" sentence="An bhfuil aon uachtar reoite agat sa samhradh (OK)?" errortext="OK" msg="Is fÃ©idir gur focal iasachta Ã© seo (tÃ¡ na litreacha /^OK/ neamhdhÃ³chÃºil)">
<E offset="28" fromy="170" fromx="28" toy="170" tox="41" sentence="TÃ¡ sÃ© brÃ¡thair de chuid Ord San Phroinsias." errortext="San Phroinsias" msg="SÃ©imhiÃº gan ghÃ¡">
<E offset="0" fromy="171" fromx="0" toy="171" tox="9" sentence="San fÃ¡sach cuirfidh mÃ© crainn chÃ©adrais." errortext="San fÃ¡sach" msg="SÃ©imhiÃº ar iarraidh">
<E offset="34" fromy="172" fromx="34" toy="172" tox="44" sentence="An bhfuil aon uachtar reoite agat san foraois?" errortext="san foraois" msg="SÃ©imhiÃº ar iarraidh">
<E offset="34" fromy="173" fromx="34" toy="173" tox="43" sentence="An bhfuil aon uachtar reoite agat sa oighear?" errortext="sa oighear" msg="Ba chÃ³ir duit /san/ a ÃºsÃ¡id anseo">
<E offset="35" fromy="174" fromx="35" toy="174" tox="42" sentence="Tugaimid faoi abhainn na Sionainne san bhÃ¡d locha Ã³ Ros ComÃ¡in." errortext="san bhÃ¡d" msg="Ba chÃ³ir duit /sa/ a ÃºsÃ¡id anseo">
<E offset="47" fromy="175" fromx="47" toy="175" tox="54" sentence="NÃ­ fÃ©idir iad a sheinm le snÃ¡thaid ach cÃºig nÃ³ sÃ© uaire." errortext="sÃ© uaire" msg="Ba chÃ³ir duit /huaire/ a ÃºsÃ¡id anseo">
<E offset="67" fromy="176" fromx="67" toy="176" tox="68" sentence="DÃºirt sÃ© uair amhÃ¡in nach raibh Ã¡it eile ar mhaith leis cÃ³naÃ­ ann (OK)." errortext="OK" msg="Is fÃ©idir gur focal iasachta Ã© seo (tÃ¡ na litreacha /^OK/ neamhdhÃ³chÃºil)">
<E offset="17" fromy="177" fromx="17" toy="177" tox="32" sentence="CÃ©ard atÃ¡ ann nÃ¡ sÃ© cathaoirleach coiste." errortext="sÃ© cathaoirleach" msg="SÃ©imhiÃº ar iarraidh">
<E offset="32" fromy="178" fromx="32" toy="178" tox="46" sentence="Cuireadh boscaÃ­ ticeÃ¡la isteach seachas bhoscaÃ­ le freagraÃ­ a scrÃ­obh isteach." errortext="seachas bhoscaÃ­" msg="SÃ©imhiÃº gan ghÃ¡">
<E offset="25" fromy="179" fromx="25" toy="179" tox="36" sentence="TÃ¡ seacht lampa air agus seacht pÃ­opa ar gach ceann dÃ­obh." errortext="seacht pÃ­opa" msg="UrÃº ar iarraidh">
<E offset="50" fromy="180" fromx="50" toy="180" tox="61" sentence="TÃ¡ ar a laghad ceithre nÃ­ sa litir a chuir scaoll sna oifigigh." errortext="sna oifigigh" msg="RÃ©amhlitir /h/ ar iarraidh">
<E offset="30" fromy="181" fromx="30" toy="181" tox="43" sentence="IomprÃ³idh siad thÃº lena lÃ¡mha sula bhuailfeÃ¡ do chos in aghaidh cloiche." errortext="sula bhuailfeÃ¡" msg="UrÃº ar iarraidh">
<E offset="4" fromy="182" fromx="4" toy="182" tox="15" sentence="Ach sular sroich sÃ©, dÃºirt sÃ­: &quot;DÃºnaigÃ­ an doras air!&quot;" errortext="sular sroich" msg="SÃ©imhiÃº ar iarraidh">
<E offset="40" fromy="183" fromx="40" toy="183" tox="51" sentence="Chuir iad ina suÃ­ mar a raibh onÃ³ir acu thar an cuid eile a fuair cuireadh." errortext="thar an cuid" msg="UrÃº nÃ³ sÃ©imhiÃº ar iarraidh">
<E offset="9" fromy="184" fromx="9" toy="184" tox="17" sentence="Timpeall trÃ­ uaire a chloig ina dhiaidh sin thÃ¡inig an bhean isteach." errortext="trÃ­ uaire" msg="Ba chÃ³ir duit /huaire/ a ÃºsÃ¡id anseo">
<E offset="58" fromy="185" fromx="58" toy="185" tox="62" sentence="ScrÃ­obhaim chugaibh mar gur maitheadh daoibh bhur bpeacaÃ­ trÃ­ a ainm." errortext="trÃ­ a" msg="Ba chÃ³ir duit /trÃ­na/ a ÃºsÃ¡id anseo">
<E offset="31" fromy="186" fromx="31" toy="186" tox="36" sentence="NÃ­ fhillfidh siad ar an ngeata trÃ­ ar ghabh siad isteach." errortext="trÃ­ ar" msg="Ba chÃ³ir duit /trÃ­nar/ a ÃºsÃ¡id anseo">
<E offset="33" fromy="187" fromx="33" toy="187" tox="38" sentence="Beirimid an bua go caithrÃ©imeach trÃ­ an tÃ© Ãºd a thug grÃ¡ dÃºinn." errortext="trÃ­ an" msg="Ba chÃ³ir duit /trÃ­d an/ a ÃºsÃ¡id anseo">
<E offset="49" fromy="188" fromx="49" toy="188" tox="54" sentence="CoinnÃ­odh lenÃ¡r sÃ¡la sa chaoi nÃ¡rbh fhÃ©idir siÃºl trÃ­ Ã¡r srÃ¡ideanna." errortext="trÃ­ Ã¡r" msg="Ba chÃ³ir duit /trÃ­nÃ¡r/ a ÃºsÃ¡id anseo">
<E offset="15" fromy="189" fromx="15" toy="189" tox="22" sentence="Gabhfaidh siad trÃ­ muir na hÃ‰igipte." errortext="trÃ­ muir" msg="SÃ©imhiÃº ar iarraidh">
<E offset="36" fromy="190" fromx="36" toy="190" tox="42" sentence="Feidhmeoidh an ciste coimisiÃºnaithe trÃ­d na foilsitheoirÃ­ go prÃ­omha." errortext="trÃ­d na" msg="Ba chÃ³ir duit /trÃ­ na/ a ÃºsÃ¡id anseo">
<E offset="4" fromy="191" fromx="4" toy="191" tox="16" sentence="Mar trÃ­nÃ¡r peacaÃ­, tÃ¡ do phobal ina Ã¡bhar gÃ¡ire ag cÃ¡ch mÃ¡guaird orainn." errortext="trÃ­nÃ¡r peacaÃ­" msg="UrÃº ar iarraidh">
<E offset="17" fromy="192" fromx="17" toy="192" tox="28" sentence="Idir dhÃ¡ sholas, um trÃ¡thnÃ³na, faoi choim na hoÃ­che agus sa dorchadas." errortext="um trÃ¡thnÃ³na" msg="SÃ©imhiÃº ar iarraidh">
<E offset="38" fromy="193" fromx="38" toy="193" tox="39" sentence="TÃ¡ sÃ©-- tÃ¡ sÃ©- mo ---shin-seanathair (OK)." errortext="OK" msg="Is fÃ©idir gur focal iasachta Ã© seo (tÃ¡ na litreacha /^OK/ neamhdhÃ³chÃºil)">
<E offset="16" fromy="194" fromx="16" toy="194" tox="22" sentence="Maidin lÃ¡ ar na mhÃ¡rach thug a fhear gaoil cuairt air." errortext="mhÃ¡rach" msg="NÃ­ ÃºsÃ¡idtear an focal seo ach san abairtÃ­n /arna mhÃ¡rach/ de ghnÃ¡th">
<E offset="23" fromy="195" fromx="23" toy="195" tox="24" sentence="Bhain na toibreacha le re eile agus le dream daoine atÃ¡ imithe." errortext="re" msg="NÃ­ ÃºsÃ¡idtear an focal seo ach san abairtÃ­n /gach re/ de ghnÃ¡th">
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
