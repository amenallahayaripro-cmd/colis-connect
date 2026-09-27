import \'dart:math\';
import \'package:flutter/material.dart\';
import \'package:barcode_widget/barcode_widget.dart\';
import \'package:qr_flutter/qr_flutter.dart\';

void main() => runApp(const ColisApp());

// --- FAUSSE BASE DE DONNÉES POUR TEST ---
enum ColisStatus { cree, attente, enCours, livre, retourProvisoire, retourDefinitif }

class Colis {
  String id; String codeBarre; String expediteurId; String? livreurId;
  String nomClient, adresse, designation; double prixArticle, prixLivraison;
  ColisStatus statut; DateTime date;
  Colis({required this.id, required this.codeBarre, required this.expediteurId, this.livreurId, required this.nomClient, required this.adresse, required this.designation, required this.prixArticle, required this.prixLivraison, required this.statut, required this.date});
}

class MockDB {
  static String currentUserId = "exp1";
  static String currentRole = "expediteur";
  static List<Colis> colis = [
    Colis(id: "1", codeBarre: "CC-77382-XB91", expediteurId: "exp1", livreurId: "liv1", nomClient: "Karim Benali", adresse: "Alger Centre", designation: "Chaussures Nike 42", prixArticle: 8500, prixLivraison: 600, statut: ColisStatus.livre, date: DateTime.now()),
    Colis(id: "2", codeBarre: "CC-77383-XB92", expediteurId: "exp1", nomClient: "Sara Lounis", adresse: "Oran", designation: "Robe", prixArticle: 4500, prixLivraison: 800, statut: ColisStatus.attente, date: DateTime.now()),
    Colis(id: "3", codeBarre: "CC-77384-XB93", expediteurId: "exp1", livreurId: "liv1", nomClient: "Amine D.", adresse: "Constantine", designation: "Montre", prixArticle: 12000, prixLivraison: 600, statut: ColisStatus.retourProvisoire, date: DateTime.now()),
  ];
}

class ColisApp extends StatelessWidget {
  const ColisApp({super.key});
  @override Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: \'Colis Connect\',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const WelcomeScreen(),
    );
  }
}

// --- WELCOME & REGISTER ---
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.local_shipping, size: 80, color: Colors.indigo),
      const Text("COLIS CONNECT", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
      const Text("Expéditeur <-> Livreur", style: TextStyle(color: Colors.grey)),
      const SizedBox(height: 40),
      ElevatedButton(onPressed: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=> const RegisterScreen())), child: const Text("S\'INSCRIRE - KYC Obligatoire")),
      TextButton(onPressed: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=> const LoginScreen())), child: const Text("J\'ai déjà un compte - Se connecter")),
    ]))));
  }
}

class RegisterScreen extends StatefulWidget { const RegisterScreen({super.key}); @override State<RegisterScreen> createState()=> _RegisterScreenState();}
class _RegisterScreenState extends State<RegisterScreen> {
  int step=0; bool cgu=false; String role="expediteur";
  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text("Inscription - Étape ${step+1}/3")), body: Stepper(currentStep: step, onStepContinue: (){
      if(step<2) setState(()=> step++); else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Demande envoyée ! Vérification sous 24-48h"))); Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=> const PendingScreen()));}
    }, onStepCancel: ()=> setState(()=> step--), controlsBuilder: (c,d){ return Padding(padding: const EdgeInsets.only(top:16), child: ElevatedButton(onPressed: (step==2 && !cgu)? null: d.onStepContinue, child: Text(step==2? "ENVOYER MA DEMANDE":"Continuer")));},
    steps: [
      Step(title: const Text("Infos Personnelles"), content: Column(children: [
        DropdownButtonFormField(value: role, items: const [DropdownMenuItem(value:"expediteur", child: Text("Je suis Expéditeur")), DropdownMenuItem(value:"livreur", child: Text("Je suis Livreur"))], onChanged:(v)=>setState(()=>role=v!), decoration: const InputDecoration(labelText: "Rôle")),
        const TextField(decoration: InputDecoration(labelText: "Nom *")), const TextField(decoration: InputDecoration(labelText: "Prénom *")),
        const TextField(decoration: InputDecoration(labelText: "Email *", hintText: "code OTP envoyé")), const TextField(decoration: InputDecoration(labelText: "Téléphone *")),
      ])),
      Step(title: const Text("Vérification Identité"), content: Column(children: [
        _uploadTile("Photo RECTO CIN / Passeport *"), _uploadTile("Photo VERSO CIN / Passeport *"), _uploadTile("Facture Eau/Électricité < 3 mois *"),
        const SizedBox(height:8), Container(color: Colors.orange.shade50, padding: const EdgeInsets.all(8), child: const Text("Filigrane auto \'COLIS CONNECT\' ajouté pour sécurité", style: TextStyle(fontSize: 12)))
      ])),
      Step(title: const Text("Validation Légale"), content: Column(children: [
        CheckboxListTile(value: cgu, onChanged:(v)=>setState(()=>cgu=v!), title: const Text("Je certifie avoir lu et accepté les CGU et la Politique de Confidentialité *"), subtitle: const Text("Voir CGU | Voir Confidentialité", style: TextStyle(color: Colors.indigo))),
      ])),
    ]));
  }
  Widget _uploadTile(String t)=> Card(child: ListTile(leading: const Icon(Icons.camera_alt, color: Colors.indigo), title: Text(t), trailing: const Icon(Icons.check_circle, color: Colors.green), onTap: (){}));
}
class PendingScreen extends StatelessWidget { const PendingScreen({super.key}); @override Widget build(BuildContext context)=> Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.hourglass_top, size: 80, color: Colors.orange), const Text("Compte en cours de vérification", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const Text("Admin vérifie vos documents sous 24-48h", textAlign: TextAlign.center), const SizedBox(height:20), ElevatedButton(onPressed: ()=> Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=> const LoginScreen())), child: const Text("Aller au Login (DEMO)"))]))));}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("Connexion DEMO")), body: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
      const TextField(decoration: InputDecoration(labelText: "Email")), const TextField(decoration: InputDecoration(labelText: "Mot de passe"), obscureText: true), const SizedBox(height:20),
      ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity,50)), onPressed: (){ MockDB.currentRole="expediteur"; Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=> const ExpediteurHome()));}, child: const Text("Se connecter comme EXPÉDITEUR")),
      const SizedBox(height:12),
      ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity,50), backgroundColor: Colors.teal), onPressed: (){ MockDB.currentRole="livreur"; Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=> const LivreurHome()));}, child: const Text("Se connecter comme LIVREUR", style: TextStyle(color: Colors.white))),
    ])));
  }
}

// --- ESPACE EXPEDITEUR ---
class ExpediteurHome extends StatefulWidget { const ExpediteurHome({super.key}); @override State<ExpediteurHome> createState()=> _ExpHomeState();}
class _ExpHomeState extends State<ExpediteurHome>{
  int idx=0;
  @override Widget build(BuildContext context){
    return Scaffold(appBar: AppBar(title: const Text("Expéditeur Dashboard"), actions: [IconButton(onPressed: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=> const CreateColisScreen())), icon: const Icon(Icons.add))]),
      body: [const DashboardExp(), const ListeColisExp(), const QrClotureScreen()][idx],
      bottomNavigationBar: NavigationBar(selectedIndex: idx, onDestinationSelected:(i)=>setState(()=>idx=i), destinations: const [NavigationDestination(icon: Icon(Icons.dashboard), label: "Dashboard"), NavigationDestination(icon: Icon(Icons.list_alt), label: "Mes Colis"), NavigationDestination(icon: Icon(Icons.qr_code), label: "Clôture")]),
      floatingActionButton: FloatingActionButton.extended(onPressed: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=> const CreateColisScreen())).then((_)=>setState((){})), label: const Text("Nouveau Bordereau"), icon: const Icon(Icons.add)),
    );
  }
}
class DashboardExp extends StatelessWidget{ const DashboardExp({super.key});
  @override Widget build(BuildContext context){
    var all = MockDB.colis.where((c)=>c.expediteurId=="exp1").toList();
    int livres = all.where((c)=>c.statut==ColisStatus.livre).length;
    int prov = all.where((c)=>c.statut==ColisStatus.retourProvisoire).length;
    int def = all.where((c)=>c.statut==ColisStatus.retourDefinitif).length;
    double aCollecter = all.where((c)=>c.statut==ColisStatus.livre).fold(0, (s,c)=>s+c.prixArticle);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [Expanded(child: _card("LIVRÉS", "$livres", Colors.green)), const SizedBox(width:8), Expanded(child: _card("PROVISOIRE", "$prov", Colors.orange)), const SizedBox(width:8), Expanded(child: _card("DÉFINITIF", "$def", Colors.red))]),
      const SizedBox(height:12),
      Card(color: Colors.indigo, child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [const Text("ARGENT À COLLECTER", style: TextStyle(color: Colors.white70)), Text("$aCollecter DA", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)), const Text("Chez le livreur - À clôturer par QR Scan", style: TextStyle(color: Colors.white70, fontSize: 12))]))),
      const SizedBox(height:12),
      const Text("Activité Récente", style: TextStyle(fontWeight: FontWeight.bold)),
      ...all.map((c)=> ListTile(leading: Icon(Icons.inventory_2, color: _color(c.statut)), title: Text(c.nomClient), subtitle: Text("${c.codeBarre} - ${_label(c.statut)}"), trailing: Text("${c.prixArticle} DA"))),
    ]);
  }
  Widget _card(String t,String v,Color c)=> Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [Text(t, style: TextStyle(fontSize: 10, color: c, fontWeight: FontWeight.bold)), Text(v, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))])));

}
class ListeColisExp extends StatelessWidget{ const ListeColisExp({super.key});
  @override Widget build(BuildContext context){
    var list = MockDB.colis.where((c)=>c.expediteurId=="exp1").toList();
    return ListView.builder(itemCount: list.length, itemBuilder: (c,i){
      var col=list[i];
      return Card(margin: const EdgeInsets.symmetric(horizontal:12, vertical:6), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(col.codeBarre, style: const TextStyle(fontWeight: FontWeight.bold)), Chip(label: Text(_label(col.statut), style: const TextStyle(fontSize:10)), backgroundColor: _color(col.statut).withOpacity(0.2))]),
        Text("${col.nomClient} - ${col.adresse}"), Text("${col.designation} - ${col.prixArticle}DA + Livraison ${col.prixLivraison}DA", style: const TextStyle(color: Colors.grey)),
        const SizedBox(height:8),
        BarcodeWidget(barcode: Barcode.code128(), data: col.codeBarre, width: double.infinity, height: 50, drawText: true),
        if(col.statut==ColisStatus.attente) Row(children: [const Icon(Icons.person_add, size:16, color: Colors.teal), const Text(" Livreur veut enlever - ", style: TextStyle(fontSize:12)), TextButton(onPressed: (){ col.statut=ColisStatus.enCours; col.livreurId="liv1"; ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text("Accepté ! Mise en contact")));}, child: const Text("ACCEPTER")), TextButton(onPressed: (){}, child: const Text("REFUSER"))])
      ])));
    });
  }
}
class QrClotureScreen extends StatelessWidget{ const QrClotureScreen({super.key});
  @override Widget build(BuildContext context){
    return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text("QR DE CLÔTURE JOURNALIÈRE", style: TextStyle(fontWeight: FontWeight.bold)),
      const Text("Le livreur doit scanner ce QR pour te rendre l\'argent + retours provisoires", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
      const SizedBox(height:16),
      QrImageView(data: "EXP1-CLOTURE-${DateTime.now().day}", version: QrVersions.auto, size: 200),
      const SizedBox(height:12), const Text("EXP1 - Ahmed Boutique", style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height:20), const Card(child: Padding(padding: EdgeInsets.all(12), child: Text("Tant que ce QR n\'est pas scanné, la journée n\'est PAS clôturée et l\'argent reste \'À collecter\'"))),
    ])));
  }
}
class CreateColisScreen extends StatefulWidget{ const CreateColisScreen({super.key}); @override State<CreateColisScreen> createState()=> _CreateState();}
class _CreateState extends State<CreateColisScreen>{
  final nom=TextEditingController(), adresse=TextEditingController(), desig=TextEditingController(), prix=TextEditingController(text:"5000"), prixLiv=TextEditingController(text:"600");
  @override Widget build(BuildContext context){
    return Scaffold(appBar: AppBar(title: const Text("Nouveau Bordereau")), body: ListView(padding: const EdgeInsets.all(16), children: [
      TextField(controller: nom, decoration: const InputDecoration(labelText: "Nom Client *", border: OutlineInputBorder())), const SizedBox(height:12),
      TextField(controller: adresse, decoration: const InputDecoration(labelText: "Adresse + Ville *", border: OutlineInputBorder())), const SizedBox(height:12),
      TextField(controller: desig, decoration: const InputDecoration(labelText: "Désignation Produit *", border: OutlineInputBorder())), const SizedBox(height:12),
      Row(children: [Expanded(child: TextField(controller: prix, decoration: const InputDecoration(labelText: "Prix Article (COD) DA", border: OutlineInputBorder()), keyboardType: TextInputType.number)), const SizedBox(width:12), Expanded(child: TextField(controller: prixLiv, decoration: const InputDecoration(labelText: "Prix Livraison DA", border: OutlineInputBorder()), keyboardType: TextInputType.number))]),
      const SizedBox(height:20),
      ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity,50), backgroundColor: Colors.indigo, foregroundColor: Colors.white), onPressed: (){
        var code="CC-${Random().nextInt(90000)+10000}-${Random().nextInt(900)+100}";
        MockDB.colis.add(Colis(id: code, codeBarre: code, expediteurId: "exp1", nomClient: nom.text.isEmpty?"Client":nom.text, adresse: adresse.text.isEmpty?"Alger":adresse.text, designation: desig.text.isEmpty?"Produit":desig.text, prixArticle: double.tryParse(prix.text)??0, prixLivraison: double.tryParse(prixLiv.text)??0, statut: ColisStatus.attente, date: DateTime.now()));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Bordereau $code créé !")));
        Navigator.pop(context);
      }, child: const Text("GÉNÉRER BORDEREAU + CODE-BARRES")),
    ]));
  }
}

// --- ESPACE LIVREUR ---
class LivreurHome extends StatefulWidget{ const LivreurHome({super.key}); @override State<LivreurHome> createState()=> _LivHomeState();}
class _LivHomeState extends State<LivreurHome>{ int idx=0;
  @override Widget build(BuildContext context){
    return Scaffold(appBar: AppBar(title: const Text("Espace Livreur"), backgroundColor: Colors.teal, foregroundColor: Colors.white),
      body: [const DemandesList(), const MesColisLivreur(), const ClotureLivreurScreen()][idx],
      bottomNavigationBar: NavigationBar(selectedIndex: idx, onDestinationSelected:(i)=>setState(()=>idx=i), destinations: const [NavigationDestination(icon: Icon(Icons.search), label: "Demandes"), NavigationDestination(icon: Icon(Icons.delivery_dining), label: "Mes Colis"), NavigationDestination(icon: Icon(Icons.qr_code_scanner), label: "Clôture")]),
    );
  }
}
class DemandesList extends StatelessWidget{ const DemandesList({super.key});
  @override Widget build(BuildContext context){
    var demandes = MockDB.colis.where((c)=>c.statut==ColisStatus.attente).toList();
    return ListView.builder(itemCount: demandes.length, itemBuilder: (c,i){
      var col=demandes[i];
      return Card(margin: const EdgeInsets.all(12), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Expéditeur: Ahmed Boutique - ${col.adresse}", style: const TextStyle(fontWeight: FontWeight.bold)), Text("Destination: ${col.adresse} | ${col.designation}"), Text("Gain: ${col.prixLivraison} DA / colis", style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
        const SizedBox(height:8), ElevatedButton(onPressed: (){ ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text("Demande envoyée à l\'expéditeur - En attente d\'acceptation")));}, child: const Text("POSTULER POUR L\'ENLÈVEMENT"))
      ])));
    });
  }
}
class MesColisLivreur extends StatefulWidget{ const MesColisLivreur({super.key}); @override State<MesColisLivreur> createState()=> _MesState();}
class _MesState extends State<MesColisLivreur>{
  @override Widget build(BuildContext context){
    var list = MockDB.colis.where((c)=>c.livreurId=="liv1" && c.statut!=ColisStatus.attente).toList();
    return ListView.builder(itemCount: list.length, itemBuilder: (c,i){
      var col=list[i];
      return Card(margin: const EdgeInsets.all(8), child: ListTile(title: Text(col.nomClient), subtitle: Text("${col.adresse} - ${col.prixArticle}DA"), trailing: PopupMenuButton(onSelected: (v){ setState((){ if(v=="livre") col.statut=ColisStatus.livre; if(v=="prov") col.statut=ColisStatus.retourProvisoire; if(v=="def") col.statut=ColisStatus.retourDefinitif; });}, itemBuilder: (_)=> const [PopupMenuItem(value:"livre", child: Text("✅ Livré - Argent Collecté")), PopupMenuItem(value:"prov", child: Text("↩️ Retour Provisoire - Demain")), PopupMenuItem(value:"def", child: Text("❌ Retour Définitif - Refus"))]), leading: Icon(Icons.circle, color: _color(col.statut))));
    });
  }
}
class ClotureLivreurScreen extends StatelessWidget{ const ClotureLivreurScreen({super.key});
  @override Widget build(BuildContext context){
    var livres = MockDB.colis.where((c)=>c.livreurId=="liv1" && c.statut==ColisStatus.livre).toList();
    double totalCollecte = livres.fold(0, (s,c)=>s+c.prixArticle);
    double gain = livres.length * 600;
    double aRendre = totalCollecte - gain;
    return Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      Card(child: Padding(padding: EdgeInsets.all(16), child: Column(children: [
        const Text("RÉCAPITULATIF JOURNÉE", style: TextStyle(fontWeight: FontWeight.bold)), const Divider(),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Colis Livrés: ${livres.length}"), Text("$totalCollecte DA Collectés")]),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Mon Gain:"), Text("$gain DA", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))]),
        const Divider(), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("À RENDRE à l\'expéditeur:", style: TextStyle(fontWeight: FontWeight.bold)), Text("$aRendre DA", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo))]),
      ]))),
      const SizedBox(height:20),
      ElevatedButton.icon(style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity,50), backgroundColor: Colors.teal, foregroundColor: Colors.white), onPressed: (){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("QR Expéditeur scanné ✅ Journée Clôturée ! Gain transféré")));}, icon: const Icon(Icons.qr_code_scanner), label: const Text("SCANNER QR EXPÉDITEUR POUR CLÔTURER")),
      const SizedBox(height:8), const Text("Ramène l\'argent + les 2 colis provisoires et scanne le QR de l\'expéditeur", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12))
    ]));
  }
}

String _label(ColisStatus s){ switch(s){ case ColisStatus.cree: return "CRÉÉ"; case ColisStatus.attente: return "EN ATTENTE"; case ColisStatus.enCours: return "EN COURS"; case ColisStatus.livre: return "LIVRÉ"; case ColisStatus.retourProvisoire: return "RETOUR PROVISOIRE"; case ColisStatus.retourDefinitif: return "RETOUR DÉFINITIF";}}
Color _color(ColisStatus s){ switch(s){ case ColisStatus.livre: return Colors.green; case ColisStatus.retourProvisoire: return Colors.orange; case ColisStatus.retourDefinitif: return Colors.red; case ColisStatus.attente: return Colors.blue; case ColisStatus.enCours: return Colors.teal; default: return Colors.grey;}}
