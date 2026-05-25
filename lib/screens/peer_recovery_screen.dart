import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/rsa_service.dart';
import '../services/peer_recovery_service.dart';

class PeerRecoveryScreen extends StatefulWidget {
  final String masterPassword;
  final Uint8List salt;

  const PeerRecoveryScreen({
    Key? key,
    required this.masterPassword,
    required this.salt,
  }) : super(key: key);

  @override
  State<PeerRecoveryScreen> createState() => _PeerRecoveryScreenState();
}

class _PeerRecoveryScreenState extends State<PeerRecoveryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _rsa = RSAService();
  final _peerService = PeerRecoveryService();
  final _emailCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();

  String? _myPublicKey;
  List<Map<String, String>> _peers = [];
  bool _loading = false;
  bool _generatingKey = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _generatingKey = true);
    try {
      await _rsa.generateAndStoreKeyPair();
      final key = await _rsa.getPublicKeyPem();
      final peers = await _peerService.getTrustedPeers();
      if (mounted) {
        setState(() {
          _myPublicKey = key;
          _peers = peers;
        });
      }
    } finally {
      if (mounted) setState(() => _generatingKey = false);
    }
  }

  Future<void> _addPeer() async {
    final email = _emailCtrl.text.trim();
    final key = _keyCtrl.text.trim();
    if (email.isEmpty || key.isEmpty) {
      _setMessage('Please fill in all fields', true);
      return;
    }
    if (!email.contains('@')) {
      _setMessage('Enter a valid email', true);
      return;
    }
    setState(() => _loading = true);
    try {
      await _peerService.addTrustedPeer(
        peerEmail: email,
        peerPublicKeyPem: key,
        masterPassword: widget.masterPassword,
        salt: widget.salt,
      );
      await _loadData();
      _emailCtrl.clear();
      _keyCtrl.clear();
      _setMessage('Trusted peer added!', false);
    } catch (e) {
      _setMessage('Failed: $e', true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _removePeer(String email) async {
    try {
      await _peerService.removeTrustedPeer(email);
      await _loadData();
      _setMessage('Peer removed', false);
    } catch (e) {
      _setMessage('Failed: $e', true);
    }
  }

  void _copyKey() {
    if (_myPublicKey == null) return;
    Clipboard.setData(ClipboardData(text: _myPublicKey!));
    _setMessage('Public key copied to clipboard', false);
  }

  void _setMessage(String msg, bool isError) {
    if (mounted) setState(() {
      _message = msg;
      _messageIsError = isError;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Trusted Peer Recovery'),
        backgroundColor: Colors.grey[900],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(10)),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                  color: Colors.blueGrey[700],
                  borderRadius: BorderRadius.circular(10)),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey[500],
              tabs: const [Tab(text: 'My Key'), Tab(text: 'Add Peer')],
            ),
          ),

          if (_message != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _messageIsError
                    ? Colors.red[900]!.withOpacity(0.25)
                    : Colors.green[900]!.withOpacity(0.25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: _messageIsError
                        ? Colors.red[800]!
                        : Colors.green[800]!),
              ),
              child: Text(_message!,
                  style: TextStyle(
                      color: _messageIsError ? Colors.red : Colors.green,
                      fontSize: 13)),
            ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // My Key tab
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Share this public key with trusted contacts so they can help recover your vault.',
                        style:
                            TextStyle(color: Colors.grey[400], fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      if (_generatingKey)
                        const Center(
                          child: Column(children: [
                            CircularProgressIndicator(color: Colors.blueGrey),
                            SizedBox(height: 12),
                            Text('Generating RSA-2048 key pair...',
                                style: TextStyle(color: Colors.grey)),
                          ]),
                        )
                      else if (_myPublicKey != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey[800]!),
                          ),
                          child: SelectableText(
                            _myPublicKey!,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontFamily: 'monospace'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _copyKey,
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('Copy Public Key'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueGrey[700],
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      Text('TRUSTED PEERS (${_peers.length})',
                          style: TextStyle(
                              color: Colors.blueGrey[300],
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2)),
                      const SizedBox(height: 10),
                      if (_peers.isEmpty)
                        Text('No trusted peers added yet',
                            style: TextStyle(color: Colors.grey[600]))
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _peers.length,
                          itemBuilder: (_, i) {
                            final peer = _peers[i];
                            return Card(
                              color: Colors.grey[900],
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              child: ListTile(
                                leading: const Icon(Icons.person_outline,
                                    color: Colors.blueGrey),
                                title: Text(peer['email'] ?? '',
                                    style: const TextStyle(
                                        color: Colors.white)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.red, size: 20),
                                  onPressed: () =>
                                      _removePeer(peer['email']!),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),

                // Add Peer tab
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add a trusted contact. Their public key will be used to securely encrypt your vault recovery secret.',
                        style:
                            TextStyle(color: Colors.grey[400], fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      _label('Peer email address'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecor('peer@example.com'),
                      ),
                      const SizedBox(height: 16),
                      _label('Peer public key (PEM format)'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _keyCtrl,
                        maxLines: 6,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontFamily: 'monospace'),
                        decoration: _inputDecor(
                            '-----BEGIN PUBLIC KEY-----\n...'),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _addPeer,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey[700],
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('Add Trusted Peer',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) =>
      Text(text, style: TextStyle(color: Colors.grey[400], fontSize: 13));

  InputDecoration _inputDecor(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
        filled: true,
        fillColor: Colors.grey[900],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[800]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.blueGrey[400]!),
        ),
      );
}
