import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'config.dart';
import 'scraper_engine.dart';
import 'server_service.dart';
import 'torbox_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ServerService.instance.init();
  // Auto-start server on app launch
  await ServerService.instance.startServer();
  runApp(const MegaScraperAddonApp());
}

class MegaScraperAddonApp extends StatelessWidget {
  const MegaScraperAddonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'sakinator-MegaScraper',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFF38BDF8),
          surface: Color(0xFF161B22),
        ),
        fontFamily: 'sans-serif',
      ),
      home: const MainDashboardScreen(),
    );
  }
}

class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  final FocusNode _startStopFocus = FocusNode();
  final FocusNode _copyManifestFocus = FocusNode();
  final FocusNode _openWebFocus = FocusNode();
  final FocusNode _refreshIpFocus = FocusNode();

  final TextEditingController _torboxKeyController = TextEditingController();
  final FocusNode _torboxInputFocus = FocusNode();
  final FocusNode _torboxSaveFocus = FocusNode();
  final FocusNode _torboxKeyLinkFocus = FocusNode();
  bool _obscureTorboxKey = true;
  bool _isValidatingTorbox = false;
  String? _torboxStatusMessage;
  bool _isTorboxValid = false;

  @override
  void initState() {
    super.initState();
    // Request initial focus on the primary action button for TV remote
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startStopFocus.requestFocus();
    });

    final currentKey = AddonConfig.instance.torboxApiKey;
    _torboxKeyController.text = currentKey;
    if (currentKey.isNotEmpty) {
      _validateTorboxKeySilent(currentKey);
    }
  }

  @override
  void dispose() {
    _startStopFocus.dispose();
    _copyManifestFocus.dispose();
    _openWebFocus.dispose();
    _refreshIpFocus.dispose();
    _torboxKeyController.dispose();
    _torboxInputFocus.dispose();
    _torboxSaveFocus.dispose();
    _torboxKeyLinkFocus.dispose();
    super.dispose();
  }

  Future<void> _validateTorboxKeySilent(String key) async {
    if (key.trim().isEmpty) return;
    final res = await TorboxService.instance.validateAccount(key.trim());
    if (mounted) {
      setState(() {
        _isTorboxValid = res['valid'] == true;
        _torboxStatusMessage = res['message'];
      });
    }
  }

  Future<void> _saveAndValidateTorbox() async {
    final key = _torboxKeyController.text.trim();
    setState(() {
      _isValidatingTorbox = true;
      _torboxStatusMessage = 'Validating key with TorBox API...';
    });

    AddonConfig.instance.torboxApiKey = key;
    await AddonConfig.instance.save();

    if (key.isEmpty) {
      setState(() {
        _isValidatingTorbox = false;
        _isTorboxValid = false;
        _torboxStatusMessage = 'TorBox integration disabled (key removed).';
      });
      return;
    }

    final res = await TorboxService.instance.validateAccount(key);
    if (mounted) {
      setState(() {
        _isValidatingTorbox = false;
        _isTorboxValid = res['valid'] == true;
        _torboxStatusMessage = res['message'] ?? (res['valid'] == true ? 'Connected' : 'Invalid Key');
      });
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF238636),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$label copied to clipboard!',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final server = ServerService.instance;
    final cfg = AddonConfig.instance;

    return Scaffold(
      body: SafeArea(
        child: ValueListenableBuilder<bool>(
          valueListenable: server.isRunning,
          builder: (context, running, _) {
            return ValueListenableBuilder<String>(
              valueListenable: server.localIp,
              builder: (context, ip, _) {
                final port = cfg.port;
                final manifestUrl = 'http://$ip:$port/manifest.json';
                final dashboardUrl = 'http://$ip:$port/configure';

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      children: [
                        // Header
                        _buildHeader(running),
                        const SizedBox(height: 20),

                        // Main Status Card
                        _buildStatusCard(running, ip, port, manifestUrl),
                        const SizedBox(height: 20),

                        // TorBox Debrid Card
                        _buildTorboxCard(),
                        const SizedBox(height: 20),

                        // Engine & Network Optimizations Card
                        _buildEngineFeaturesCard(),
                        const SizedBox(height: 20),

                        // Action Buttons (TV Remote Focusable)
                        _buildActionButtons(running, manifestUrl, dashboardUrl),
                        const SizedBox(height: 20),

                        // Live Info Row (Providers & Requests)
                        _buildInfoRow(),
                        const SizedBox(height: 20),

                        // Live Logs Card
                        _buildLogsCard(),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(bool running) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF6366F1), width: 1.5),
          ),
          child: const Center(
            child: Icon(Icons.bolt_rounded, color: Color(0xFF818CF8), size: 32),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'sakinator-MegaScraper',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Addon Server for Nuvio & Stremio (Android TV & Mobile)',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: running ? const Color(0xFF238636).withOpacity(0.2) : Colors.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: running ? const Color(0xFF3FB950) : Colors.redAccent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: running ? const Color(0xFF3FB950) : Colors.redAccent,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                running ? 'ONLINE' : 'OFFLINE',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 0.5,
                  color: running ? const Color(0xFF3FB950) : Colors.redAccent,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(bool running, String ip, int port, String manifestUrl) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF30363D), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.router_rounded, color: Color(0xFF38BDF8), size: 22),
              const SizedBox(width: 8),
              const Text(
                'Nuvio Addon Manifest URL',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Spacer(),
              _TvFocusableButton(
                focusNode: _refreshIpFocus,
                onPressed: () async {
                  await ServerService.instance.updateLanIp();
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF38BDF8)),
                    SizedBox(width: 6),
                    Text('Detect IP', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF21262D)),
            ),
            child: Row(
              children: [
                const Icon(Icons.link_rounded, color: Color(0xFF818CF8), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: SelectableText(
                    manifestUrl,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7EE787),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Paste this URL into Nuvio (Settings -> Addons -> Add Addon) or Stremio.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildTorboxCard() {
    final hasKey = _torboxKeyController.text.trim().isNotEmpty;
    Color statusColor;
    String statusBadgeText;
    IconData statusIcon;

    if (!hasKey) {
      statusColor = const Color(0xFF8B949E);
      statusBadgeText = 'OPTIONAL';
      statusIcon = Icons.info_outline_rounded;
    } else if (_isValidatingTorbox) {
      statusColor = const Color(0xFF58A6FF);
      statusBadgeText = 'VALIDATING...';
      statusIcon = Icons.sync_rounded;
    } else if (_isTorboxValid) {
      statusColor = const Color(0xFF3FB950);
      statusBadgeText = 'CONNECTED';
      statusIcon = Icons.check_circle_rounded;
    } else {
      statusColor = const Color(0xFFF85149);
      statusBadgeText = 'INVALID KEY';
      statusIcon = Icons.error_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isTorboxValid ? const Color(0xFF238636) : const Color(0xFF30363D),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_sync_rounded, color: Color(0xFF38BDF8), size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'TorBox Debrid Integration',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 14),
                    const SizedBox(width: 5),
                    Text(
                      statusBadgeText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Enables 1-click cloud streaming and instant caching for HubCloud, PixelDrain, and direct hosters via TorBox CDNs with high-speed byte seeking in Nuvio.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          // API Key Input
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF21262D)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(Icons.vpn_key_rounded, color: Color(0xFF818CF8), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    focusNode: _torboxInputFocus,
                    controller: _torboxKeyController,
                    obscureText: _obscureTorboxKey,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      color: Colors.white,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Enter TorBox API Key (manual input only)',
                      hintStyle: TextStyle(color: Color(0xFF484F58), fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                    ),
                    onFieldSubmitted: (_) => _saveAndValidateTorbox(),
                  ),
                ),
                IconButton(
                  tooltip: _obscureTorboxKey ? 'Show API Key' : 'Hide API Key',
                  icon: Icon(
                    _obscureTorboxKey ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureTorboxKey = !_obscureTorboxKey;
                    });
                  },
                ),
                if (_torboxKeyController.text.isNotEmpty)
                  IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.clear_rounded, color: Colors.grey, size: 18),
                    onPressed: () {
                      _torboxKeyController.clear();
                      _saveAndValidateTorbox();
                    },
                  ),
                const SizedBox(width: 4),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Action Buttons: Save & Validate, Open TorBox Settings
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _TvFocusableButton(
                focusNode: _torboxSaveFocus,
                isPrimary: true,
                primaryColor: const Color(0xFF238636),
                onPressed: _isValidatingTorbox ? () {} : _saveAndValidateTorbox,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isValidatingTorbox)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      else
                        const Icon(Icons.save_rounded, size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      const Text(
                        'Save & Validate',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              _TvFocusableButton(
                focusNode: _torboxKeyLinkFocus,
                onPressed: () async {
                  const url = 'https://torbox.app/settings';
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    _copyToClipboard(url, 'TorBox Settings URL');
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.launch_rounded, size: 16, color: Color(0xFF38BDF8)),
                      SizedBox(width: 6),
                      Text(
                        'Get Key (torbox.app)',
                        style: TextStyle(fontSize: 13, color: Color(0xFF38BDF8), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_torboxStatusMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: (_isTorboxValid ? const Color(0xFF238636) : const Color(0xFF21262D)).withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isTorboxValid ? const Color(0xFF3FB950).withOpacity(0.4) : const Color(0xFF30363D),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isTorboxValid ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
                    color: _isTorboxValid ? const Color(0xFF3FB950) : const Color(0xFF8B949E),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _torboxStatusMessage!,
                      style: TextStyle(
                        fontSize: 13,
                        color: _isTorboxValid ? const Color(0xFF7EE787) : const Color(0xFFC9D1D9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEngineFeaturesCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.speed_rounded, color: Color(0xFF818CF8), size: 22),
              SizedBox(width: 10),
              Text(
                'Engine & Network Optimizations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildFeatureBadge(
                icon: Icons.shield_rounded,
                title: 'DoH DNS Fallback',
                subtitle: 'Cloudflare & Google (Active)',
                color: const Color(0xFF238636),
              ),
              _buildFeatureBadge(
                icon: Icons.memory_rounded,
                title: 'HLS Segment Cache',
                subtitle: '35 MB Ring Buffer (Active)',
                color: const Color(0xFF1F6FEB),
              ),
              _buildFeatureBadge(
                icon: Icons.video_settings_rounded,
                title: 'MPEG-DASH Transmuxer',
                subtitle: 'Virtual HLS Converter (Ready)',
                color: const Color(0xFF7928CA),
              ),
              _buildFeatureBadge(
                icon: Icons.electric_bolt_rounded,
                title: 'Auto Circuit Breaker',
                subtitle: '56 Providers Monitored',
                color: const Color(0xFFD29922),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBadge({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF21262D)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF8B949E),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool running, String manifestUrl, String dashboardUrl) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        // Start / Stop Toggle
        _TvFocusableButton(
          focusNode: _startStopFocus,
          isPrimary: true,
          primaryColor: running ? const Color(0xFFDA3633) : const Color(0xFF238636),
          onPressed: () async {
            if (running) {
              await ServerService.instance.stopServer();
            } else {
              await ServerService.instance.startServer();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  running ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  size: 24,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Text(
                  running ? 'Stop Server' : 'Start Server',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
        ),

        // Copy Manifest URL
        _TvFocusableButton(
          focusNode: _copyManifestFocus,
          onPressed: () {
            _copyToClipboard(manifestUrl, 'Addon Manifest URL');
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.copy_rounded, size: 22, color: Color(0xFF818CF8)),
                SizedBox(width: 10),
                Text(
                  'Copy Manifest URL',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
        ),

        // Open Web Dashboard
        _TvFocusableButton(
          focusNode: _openWebFocus,
          onPressed: () async {
            final uri = Uri.parse(dashboardUrl);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } else {
              _copyToClipboard(dashboardUrl, 'Web Dashboard URL');
            }
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.open_in_browser_rounded, size: 22, color: Color(0xFF38BDF8)),
                SizedBox(width: 10),
                Text(
                  'Open Web Dashboard',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow() {
    final activeCount = ScraperEngine.instance.activeScrapers.length;
    final totalCount = ScraperEngine.instance.getProviderList().length;

    return Row(
      children: [
        // Providers Metric Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.hub_rounded, color: Color(0xFF818CF8), size: 28),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$activeCount / $totalCount Active',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Scraper Providers',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),

        // Requests Metric Card
        Expanded(
          child: ValueListenableBuilder<int>(
            valueListenable: ServerService.instance.requestCount,
            builder: (context, count, _) {
              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF238636).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.sync_alt_rounded, color: Color(0xFF3FB950), size: 28),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$count Requests',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Handled this session',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLogsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.terminal_rounded, color: Colors.grey, size: 20),
              SizedBox(width: 8),
              Text(
                'Live Server Activity',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 160,
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF21262D)),
            ),
            child: ValueListenableBuilder<List<String>>(
              valueListenable: ServerService.instance.logs,
              builder: (context, logs, _) {
                if (logs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No requests yet. Listening on local network...',
                      style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final item = logs[logs.length - 1 - index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Color(0xFF8B949E),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// D-Pad and remote-friendly focusable button for Android TV & Mobile
class _TvFocusableButton extends StatefulWidget {
  final FocusNode? focusNode;
  final VoidCallback onPressed;
  final Widget child;
  final bool isPrimary;
  final Color? primaryColor;

  const _TvFocusableButton({
    this.focusNode,
    required this.onPressed,
    required this.child,
    this.isPrimary = false,
    this.primaryColor,
  });

  @override
  State<_TvFocusableButton> createState() => _TvFocusableButtonState();
}

class _TvFocusableButtonState extends State<_TvFocusableButton> {
  bool _isFocused = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final hasHighlight = _isFocused || _isHovered;
    final bg = widget.isPrimary
        ? (widget.primaryColor ?? const Color(0xFF6366F1))
        : (hasHighlight ? const Color(0xFF21262D) : const Color(0xFF161B22));

    return FocusableActionDetector(
      focusNode: widget.focusNode,
      autofocus: false,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onShowHoverHighlight: (hovered) => setState(() => _isHovered = hovered),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => widget.onPressed(),
        ),
      },
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          transform: hasHighlight ? Matrix4.diagonal3Values(1.05, 1.05, 1.0) : Matrix4.identity(),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasHighlight ? const Color(0xFF58A6FF) : const Color(0xFF30363D),
              width: hasHighlight ? 2.5 : 1.2,
            ),
            boxShadow: hasHighlight
                ? [
                    BoxShadow(
                      color: const Color(0xFF58A6FF).withOpacity(0.35),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
