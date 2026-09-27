import \'dart:io\';
import \'dart:math\';
import \'package:flutter/material.dart\';
import \'package:firebase_core/firebase_core.dart\';
import \'package:firebase_auth/firebase_auth.dart\';
import \'package:cloud_firestore/cloud_firestore.dart\';
import \'package:firebase_storage/firebase_storage.dart\';
import \'package:barcode_widget/barcode_widget.dart\';
import \'package:qr_flutter/qr_flutter.dart\';
import \'package:image_picker/image_picker.dart\';
import \'package:mobile_scanner/mobile_scanner.dart\';
import \'firebase_options.dart\';
import \'admin_dashboard.dart\';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ColisApp());
}

class ColisApp extends StatelessWidget { const ColisApp({super.key});
  @override Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, title: \'Colis Connect\', theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo), home: const AuthGate());
  }
}

class AuthGate extends StatelessWidget { const AuthGate({super.key});
  @override Widget build(BuildContext context) {
    return StreamBuilder<User?>(stream: FirebaseAuth.instance.authStateChanges(), builder: (c,snap){
      if(snap.connectionState==ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      if(!snap.hasData) return const WelcomeScreen();
      return FutureBuilder<DocumentSnapshot>(future: FirebaseFirestore.instance.collection(\'users\').doc(snap.data!.uid).get(), builder: (c, uSnap){
        if(!uSnap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        var data = uSnap.data!.data() as Map<String,dynamic>?;
        if(data==null || data[\'kyc_statut\']==\'en_attente\') return const PendingScreen();
        if(data[\'kyc_statut\']==\'refuse\') return const Scaffold(body: Center(child: Text("Compte refusé - Renvoyez vos documents")));
        if(data[\'role\']==\'admin\') return const AdminDashboard();
        if(data[\'role\']==\'livreur\') return const LivreurHome();
        return const ExpediteurHome();
      });
    });
  }
}

// --- WELCOME ---
class WelcomeScreen extends StatelessWidget { const WelcomeScreen({super.key});
  @override Widget build(BuildContext context) => Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.local_shipping, size: 80, color: Colors.indigo), const Text("COLIS CONNECT", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
    const SizedBox(height: 32),
    ElevatedButton(onPressed: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=> const RegisterScreen())), child: const Text("S\'INSCRIRE - KYC Obligatoire")),
    TextButton(onPressed: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=> const LoginScreen())), child: const Text("Se connecter")),
  ]))));
}

class LoginScreen extends StatefulWidget { const LoginScreen({super.key}); @override State<LoginScreen> createState()=> _LoginState();}
class _LoginState extends State<LoginScreen>{ final email=TextEditingController(), pass=TextEditingController(); @override Widget build(BuildContext context)=> Scaffold(appBar: AppBar(title: const Text("Connexion")), body: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
  TextField(controller: email, decoration: const InputDecoration(labelText: "Email")), TextField(controller: pass, decoration: const InputDecoration(labelText: "Mot de passe"), obscureText: true), const SizedBox(height: 20),
  ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)), onPressed: () async { try{ await FirebaseAuth.instance.signInWithEmailAndPassword(email: email.text.trim(), password: pass.text.trim()); Navigator.pop(context); }catch(e){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));} }, child: const Text("SE CONNECTER"))
])));}

class PendingScreen extends StatelessWidget { const PendingScreen({super.key}); @override Widget build(BuildContext context)=> Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.hourglass_top, size: 70, color: Colors.orange), const Text("Compte en cours de vérification", style: TextStyle(fontWeight: FontWeight.bold)), const Text("24-48h - Vous recevrez un email"), const SizedBox(height: 16), TextButton(onPressed: () async => await FirebaseAuth.instance.signOut(), child: const Text("Se déconnecter"))])));}

// --- REGISTER KYC ---
class RegisterScreen extends StatefulWidget { const RegisterScreen({super.key}); @override State<RegisterScreen> createState()=> _RegState();}
class _RegState extends State<RegisterScreen>{
  int step=0; bool cgu=false; String role="expediteur";
  final nom=TextEditingController(), prenom=TextEditingController(), email=TextEditingController(), tel=TextEditingController(), pass=TextEditingController();
  XFile? recto, verso, facture; final picker=ImagePicker();
  Future pick(bool isRecto, bool isVerso) async { var f=await picker.pickImage(source: ImageSource.camera, imageQuality: 70); if(f!=null) setState((){ if(isRecto) recto=f; else if(isVerso) verso=f; else facture=f; });}
  @override Widget build(BuildContext context){
    return Scaffold(appBar: AppBar(title: Text("Inscription ${step+1}/3")), body: Stepper(currentStep: step, onStepContinue: () async {
      if(step<2){ setState(()=>step++); return;}
      if(recto==null||verso==null||facture==null){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Toutes les photos sont obligatoires"))); return;}
      if(!cgu){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vous devez accepter les CGU"))); return;}
      try{
        var cred=await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email.text.trim(), password: pass.text.trim());
        await cred.user!.sendEmailVerification();
        String uid=cred.user!.uid;
        String rUrl=await FirebaseStorage.instance.ref(\'kyc/$uid/recto.jpg\').putFile(File(recto!.path)).then((s)=>s.ref.getDownloadURL());
        String vUrl=await FirebaseStorage.instance.ref(\'kyc/$uid/verso.jpg\').putFile(File(verso!.path)).then((s)=>s.ref.getDownloadURL());
        String fUrl=await FirebaseStorage.instance.ref(\'kyc/$uid/facture.jpg\').putFile(File(facture!.path)).then((s)=>s.ref.getDownloadURL());
        await FirebaseFirestore.instance.collection(\'users\').doc(uid).set({\'nom\':nom.text,\'prenom\':prenom.text,\'email\':email.text,\'tel\':tel.text,\'role\':role,\'kyc_statut\':\'en_attente\',\'id_recto_url\':rUrl,\'id_verso_url\':vUrl,\'justificatif_url\':fUrl,\'cgu_accepte\':true,\'date_inscription\':FieldValue.serverTimestamp()});
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=> const PendingScreen()));
      }catch(e){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));}
    }, onStepCancel: ()=> setState(()=> step--), controlsBuilder: (c,d)=> Padding(padding: const EdgeInsets.only(top:16), child: ElevatedButton(onPressed: d.onStepContinue, child: Text(step==2?"ENVOYER MA DEMANDE":"Continuer"))),
    steps: [
      Step(title: const Text("Infos"), content: Column(children: [
        DropdownButtonFormField(value: role, items: const [DropdownMenuItem(value:"expediteur", child: Text("Je suis Expéditeur")), DropdownMenuItem(value:"livreur", child: Text("Je suis Livreur"))], onChanged:(v)=>setState(()=>role=v!)),
        TextField(controller: nom, decoration: const InputDecoration(labelText: "Nom *")), TextField(controller: prenom, decoration: const InputDecoration(labelText: "Prénom *")),
        TextField(controller: email, decoration: const InputDecoration(labelText: "Email *")), TextField(controller: tel, decoration: const InputDecoration(labelText: "Téléphone *")), TextField(controller: pass, decoration: const InputDecoration(labelText: "Mot de passe *"), obscureText: true),
      ])),
      Step(title: const Text("KYC"), content: Column(children: [
        ListTile(leading: const Icon(Icons.camera_alt), title: Text(recto==null?"Photo RECTO CIN/Passeport *":"RECTO OK ✅"), onTap: ()=>pick(true,false), trailing: const Icon(Icons.chevron_right)),
        ListTile(leading: const Icon(Icons.camera_alt), title: Text(verso==null?"Photo VERSO CIN/Passeport *":"VERSO OK ✅"), onTap: ()=>pick(false,true), trailing: const Icon(Icons.chevron_right)),
        ListTile(leading: const Icon(Icons.receipt), title: Text(facture==null?"Facture Eau/Elec <3 mois *":"FACTURE OK ✅"), onTap: ()=>pick(false,false), trailing: const Icon(Icons.chevron_right)),
      ])),
      Step(title: const Text("CGU"), content: CheckboxListTile(value: cgu, onChanged:(v)=>setState(()=>cgu=v!), title: const Text("Je certifie avoir lu et accepté les CGU et Politique de confidentialité *"))),
    ]));
  }
}

// --- EXPEDITEUR ---
class ExpediteurHome extends StatefulWidget { const ExpediteurHome({super.key}); @override State<ExpediteurHome> createState()=> _ExpState();}
class _ExpState extends State<ExpediteurHome>{ int idx=0; @override Widget build(BuildContext context)=> Scaffold(appBar: AppBar(title: const Text("Expéditeur"), actions: [IconButton(onPressed: ()=> FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout))]), body: [const DashboardExp(), const ListeColisExp(), const QrClotureExp()][idx], bottomNavigationBar: NavigationBar(selectedIndex: idx, onDestinationSelected:(i)=>setState(()=>idx=i), destinations: const [NavigationDestination(icon: Icon(Icons.dashboard), label: "Dashboard"), NavigationDestination(icon: Icon(Icons.list), label: "Colis"), NavigationDestination(icon: Icon(Icons.qr_code), label: "Clôture")]), floatingActionButton: FloatingActionButton.extended(onPressed: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=> const CreateColisScreen())), label: const Text("Bordereau"), icon: const Icon(Icons.add)));}

class DashboardExp extends StatelessWidget { const DashboardExp({super.key});
  @override Widget build(BuildContext context){
    String uid=FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection(\'colis\').where(\'expediteurId\', isEqualTo: uid).snapshots(), builder: (c,snap){
      if(!snap.hasData) return const Center(child: CircularProgressIndicator());
      var all=snap.data!.docs; int livres=all.where((d)=> (d.data() as Map)[\'statut\']==\'livre\').length; int prov=all.where((d)=> (d.data() as Map)[\'statut\']==\'retourProvisoire\').length; int def=all.where((d)=> (d.data() as Map)[\'statut\']==\'retourDefinitif\').length;
      double aCollecter=0; for(var d in all){ var m=d.data() as Map; if(m[\'statut\']==\'livre\') aCollecter+= (m[\'prixArticle\'] as num).toDouble();}
      return ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [Text("$livres", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)), const Text("LIVRÉS", style: TextStyle(fontSize: 10))])))), Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [Text("$prov", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange)), const Text("PROVISOIRE", style: TextStyle(fontSize: 10))])))), Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [Text("$def", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red)), const Text("DÉFINITIF", style: TextStyle(fontSize: 10))]))))]),
        Card(color: Colors.indigo, child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [const Text("ARGENT À COLLECTER", style: TextStyle(color: Colors.white70)), Text("$aCollecter DA", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold))]))),
        ...all.map((d){ var m=d.data() as Map; return ListTile(title: Text(m[\'nomClient\']), subtitle: Text("${m[\'codeBarre\']} - ${m[\'statut\']}"), trailing: Text("${m[\'prixArticle\']} DA"));}),
      ]);
    });
  }
}

class ListeColisExp extends StatelessWidget { const ListeColisExp({super.key});
  @override Widget build(BuildContext context){
    String uid=FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection(\'colis\').where(\'expediteurId\', isEqualTo: uid).snapshots(), builder: (c,snap){
      if(!snap.hasData) return const Center(child: CircularProgressIndicator());
      return ListView.builder(itemCount: snap.data!.docs.length, itemBuilder: (c,i){
        var doc=snap.data!.docs[i]; var m=doc.data() as Map;
        return Card(margin: const EdgeInsets.all(8), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(m[\'codeBarre\'], style: const TextStyle(fontWeight: FontWeight.bold)), Chip(label: Text(m[\'statut\'], style: const TextStyle(fontSize: 10)))]),
          Text("${m[\'nomClient\']} - ${m[\'adresse\']}"), Text("${m[\'designation\']} - ${m[\'prixArticle\']} DA + Liv ${m[\'prixLivraison\']} DA"),
          const SizedBox(height: 8), BarcodeWidget(barcode: Barcode.code128(), data: m[\'codeBarre\'], width: double.infinity, height: 50, drawText: true),
          if(m[\'statut\']==\'attente\') TextButton(onPressed: (){}, child: const Text("En attente d\'un livreur...")),
          if(m[\'livreurId\']!=null && m[\'statut\']==\'attente\') Row(children: [ElevatedButton(onPressed: ()=> doc.reference.update({\'statut\':\'enCours\'}), child: const Text("ACCEPTER LIVREUR")), const SizedBox(width: 8), OutlinedButton(onPressed: ()=> doc.reference.update({\'livreurId\':null}), child: const Text("REFUSER"))]),
        ])));
      });
    });
  }
}

class QrClotureExp extends StatelessWidget { const QrClotureExp({super.key});
  @override Widget build(BuildContext context){
    String uid=FirebaseAuth.instance.currentUser!.uid;
    return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text("QR DE CLÔTURE", style: TextStyle(fontWeight: FontWeight.bold)), const Text("Le livreur scanne ce QR pour te rendre l\'argent", textAlign: TextAlign.center),
      const SizedBox(height: 16), QrImageView(data: uid, size: 220), Text(uid, style: const TextStyle(fontSize: 10)),
    ])));
  }
}

class CreateColisScreen extends StatefulWidget { const CreateColisScreen({super.key}); @override State<CreateColisScreen> createState()=> _CreateState();}
class _CreateState extends State<CreateColisScreen>{
  final nom=TextEditingController(), adresse=TextEditingController(), desig=TextEditingController(), prix=TextEditingController(text:"5000"), prixLiv=TextEditingController(text:"600");
  @override Widget build(BuildContext context)=> Scaffold(appBar: AppBar(title: const Text("Nouveau Bordereau")), body: ListView(padding: const EdgeInsets.all(16), children: [
    TextField(controller: nom, decoration: const InputDecoration(labelText: "Nom Client *", border: OutlineInputBorder())), const SizedBox(height:12),
    TextField(controller: adresse, decoration: const InputDecoration(labelText: "Adresse *", border: OutlineInputBorder())), const SizedBox(height:12),
    TextField(controller: desig, decoration: const InputDecoration(labelText: "Désignation *", border: OutlineInputBorder())), const SizedBox(height:12),
    Row(children: [Expanded(child: TextField(controller: prix, decoration: const InputDecoration(labelText: "Prix Article DA", border: OutlineInputBorder()), keyboardType: TextInputType.number)), const SizedBox(width:12), Expanded(child: TextField(controller: prixLiv, decoration: const InputDecoration(labelText: "Prix Livraison DA", border: OutlineInputBorder()), keyboardType: TextInputType.number))]),
    const SizedBox(height: 20),
    ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity,50), backgroundColor: Colors.indigo, foregroundColor: Colors.white), onPressed: () async {
      String uid=FirebaseAuth.instance.currentUser!.uid; String code="CC-${Random().nextInt(90000)+10000}-${Random().nextInt(900)+100}";
      await FirebaseFirestore.instance.collection(\'colis\').add({\'codeBarre\':code,\'expediteurId\':uid,\'livreurId\':null,\'nomClient\':nom.text.isEmpty?"Client":nom.text,\'adresse\':adresse.text,\'designation\':desig.text,\'prixArticle\':double.tryParse(prix.text)??0,\'prixLivraison\':double.tryParse(prixLiv.text)??0,\'statut\':\'attente\',\'date\':FieldValue.serverTimestamp()});
      Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Bordereau $code créé")));
    }, child: const Text("GÉNÉRER BORDEREAU")),
  ]));
}

// --- LIVREUR ---
class LivreurHome extends StatefulWidget { const LivreurHome({super.key}); @override State<LivreurHome> createState()=> _LivState();}
class _LivState extends State<LivreurHome>{ int idx=0; @override Widget build(BuildContext context)=> Scaffold(appBar: AppBar(title: const Text("Livreur"), backgroundColor: Colors.teal, foregroundColor: Colors.white, actions: [IconButton(onPressed: ()=> FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout))]), body: [const DemandesList(), const MesColisLivreur(), const ClotureLivreur()][idx], bottomNavigationBar: NavigationBar(selectedIndex: idx, onDestinationSelected:(i)=>setState(()=>idx=i), destinations: const [NavigationDestination(icon: Icon(Icons.search), label: "Demandes"), NavigationDestination(icon: Icon(Icons.delivery_dining), label: "Mes Colis"), NavigationDestination(icon: Icon(Icons.qr_code_scanner), label: "Clôture")]));}

class DemandesList extends StatelessWidget { const DemandesList({super.key});
  @override Widget build(BuildContext context){
    return StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection(\'colis\').where(\'statut\', isEqualTo: \'attente\').snapshots(), builder: (c,snap){
      if(!snap.hasData) return const Center(child: CircularProgressIndicator());
      if(snap.data!.docs.isEmpty) return const Center(child: Text("Aucune demande"));
      return ListView.builder(itemCount: snap.data!.docs.length, itemBuilder: (c,i){
        var doc=snap.data!.docs[i]; var m=doc.data() as Map;
        return Card(margin: const EdgeInsets.all(12), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Expéditeur: ${m[\'expediteurId\'].toString().substring(0,6)} - ${m[\'adresse\']}", style: const TextStyle(fontWeight: FontWeight.bold)), Text(m[\'designation\']), Text("Gain ${m[\'prixLivraison\']} DA", style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
          ElevatedButton(onPressed: () async { String uid=FirebaseAuth.instance.currentUser!.uid; await doc.reference.update({\'livreurId\':uid}); ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text("Demande envoyée - Attente acceptation")));}, child: const Text("POSTULER"))
        ])));
      });
    });
  }
}

class MesColisLivreur extends StatelessWidget { const MesColisLivreur({super.key});
  @override Widget build(BuildContext context){
    String uid=FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection(\'colis\').where(\'livreurId\', isEqualTo: uid).snapshots(), builder: (c,snap){
      if(!snap.hasData) return const Center(child: CircularProgressIndicator());
      return ListView.builder(itemCount: snap.data!.docs.length, itemBuilder: (c,i){
        var doc=snap.data!.docs[i]; var m=doc.data() as Map;
        return Card(child: ListTile(title: Text(m[\'nomClient\']), subtitle: Text("${m[\'adresse\']} - ${m[\'prixArticle\']} DA - ${m[\'statut\']}"), trailing: PopupMenuButton(onSelected:(v)=> doc.reference.update({\'statut\':v}), itemBuilder: (_)=> const [PopupMenuItem(value:"livre", child: Text("✅ Livré")), PopupMenuItem(value:"retourProvisoire", child: Text("↩️ Provisoire")), PopupMenuItem(value:"retourDefinitif", child: Text("❌ Définitif"))])));
      });
    });
  }
}

class ClotureLivreur extends StatelessWidget { const ClotureLivreur({super.key});
  @override Widget build(BuildContext context){
    String uid=FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection(\'colis\').where(\'livreurId\', isEqualTo: uid).where(\'statut\', isEqualTo: \'livre\').snapshots(), builder: (c,snap){
      double total=0; int nb=snap.data?.docs.length ?? 0; if(snap.hasData) for(var d in snap.data!.docs) total+= ((d.data() as Map)[\'prixArticle\'] as num).toDouble();
      double gain=nb*600; double aRendre= total - gain;
      return Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          const Text("RÉCAP CLÔTURE", style: TextStyle(fontWeight: FontWeight.bold)), const Divider(),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Colis livrés: $nb"), Text("$total DA")]),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Mon gain:"), Text("$gain DA", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))]),
          const Divider(), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("À RENDRE:", style: TextStyle(fontWeight: FontWeight.bold)), Text("$aRendre DA", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 18))]),
        ]))),
        const SizedBox(height: 20),
        ElevatedButton.icon(style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity,50), backgroundColor: Colors.teal, foregroundColor: Colors.white), onPressed: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=> const ScannerScreen())), icon: const Icon(Icons.qr_code_scanner), label: const Text("SCANNER QR EXPÉDITEUR")),
      ]));
    });
  }
}

class ScannerScreen extends StatelessWidget { const ScannerScreen({super.key});
  @override Widget build(BuildContext context){
    return Scaffold(appBar: AppBar(title: const Text("Scanner QR")), body: MobileScanner(onDetect: (cap) async {
      final code=cap.barcodes.first.rawValue; if(code==null) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("QR Scanné: $code - Journée clôturée ✅")));
      Navigator.pop(context);
    }));
  }
}
