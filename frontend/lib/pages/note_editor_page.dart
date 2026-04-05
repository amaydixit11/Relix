import 'package:flutter/material.dart';
import '../models.dart';
import '../services/relix_controller.dart';

class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({super.key, required this.controller, this.existing});

  final RelixController controller;
  final NoteEntry? existing;

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final TextEditingController _tagsController;
  bool _saving = false;
  bool _hasConflict = false;

  @override
  void initState() {
    super.initState();
    final noteContent = widget.existing?.content as NoteContent?;
    _titleController = TextEditingController(text: noteContent?.title ?? '');
    _bodyController = TextEditingController(text: noteContent?.body ?? '');
    _tagsController = TextEditingController(
      text:
          widget.existing?.tags.where((tag) => !tag.contains(':')).join(', ') ??
          '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded, color: Colors.white60),
        ),
        title: Text(
          widget.existing == null ? 'Drafting Neural Note' : 'Refining Memory',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
            fontSize: 18,
          ),
        ),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF2DD4BF),
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton(
                onPressed: _save,
                child: const Text(
                  'COMMIT',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    fontSize: 12,
                    color: Color(0xFF2DD4BF),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF020617), Color(0xFF0F172A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            children: [
              if (_hasConflict)
                _StatusAlert(
                  color: Colors.orangeAccent,
                  text: 'Divergent history detected. Remote changes exist.',
                  icon: Icons.history_edu_rounded,
                ),

              TextField(
                controller: _titleController,
                autofocus: widget.existing == null,
                style: Theme.of(context).textTheme.headlineLarge,
                decoration: InputDecoration(
                  hintText: 'Neural Trace Title...',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  const Icon(
                    Icons.tag_rounded,
                    size: 16,
                    color: Colors.white24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _tagsController,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF2DD4BF),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'ASSOCIATE TAGS...',
                        hintStyle: TextStyle(
                          color: Colors.white10,
                          fontSize: 11,
                          letterSpacing: 1,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              TextField(
                controller: _bodyController,
                minLines: 15,
                maxLines: null,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white70,
                  height: 1.6,
                  fontFamily: 'serif', // Elegant reading experience
                ),
                decoration: InputDecoration(
                  hintText:
                      'Expand your consciousness here...\n\nConnect logic with [[wikilinks]].',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.05),
                    fontStyle: FontStyle.italic,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),

              const SizedBox(height: 64),
              if (widget.existing != null)
                OutlinedButton.icon(
                  onPressed: () async {
                    final latest = await widget.controller
                        .fetchLatestRemoteNote(widget.existing!.id);
                    if (mounted) {
                      setState(
                        () => _hasConflict =
                            latest != null &&
                            latest.updatedAt >
                                (widget.existing?.updatedAt ?? 0),
                      );
                    }
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('SYNC CHECK'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white24,
                    side: const BorderSide(color: Colors.white10),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final title = _titleController.text.trim().isEmpty
        ? 'Untitled'
        : _titleController.text.trim();
    final body = _bodyController.text;
    final tags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    setState(() => _saving = true);
    try {
      if (widget.existing == null) {
        await widget.controller.createNote(
          title: title,
          body: body,
          tags: tags,
        );
      } else {
        await widget.controller.updateNote(
          id: widget.existing!.id,
          title: title,
          body: body,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(
              'Transmission Failed: $e',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }
    }
  }
}

class _StatusAlert extends StatelessWidget {
  const _StatusAlert({
    required this.color,
    required this.text,
    required this.icon,
  });
  final Color color;
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
