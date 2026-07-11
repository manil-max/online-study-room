import 'package:flutter/material.dart';
import 'package:online_study_room/core/theme/app_theme.dart';

class CustomPaletteEditor extends StatefulWidget {
  final AppPalette initialPalette;
  final String title;

  const CustomPaletteEditor({
    super.key,
    required this.initialPalette,
    required this.title,
  });

  @override
  State<CustomPaletteEditor> createState() => _CustomPaletteEditorState();
}

class _CustomPaletteEditorState extends State<CustomPaletteEditor> {
  late Color _primary;
  late Color _accent;
  late TextEditingController _nameController;

  final List<Color> _colorOptions = const [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
    Color(0xFF8B5CF6), // Mor Gece primary
    Color(0xFF34D399), // Mint
    Color(0xFFF43F5E), // Rose
  ];

  @override
  void initState() {
    super.initState();
    _primary = widget.initialPalette.primary;
    _accent = widget.initialPalette.accent;
    _nameController = TextEditingController(text: widget.initialPalette.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Widget _buildColorGrid(Color selectedColor, ValueChanged<Color> onSelect) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _colorOptions.length,
      itemBuilder: (context, index) {
        final color = _colorOptions[index];
        final isSelected = color.toARGB32() == selectedColor.toARGB32();
        return GestureDetector(
          onTap: () => onSelect(color),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
            ),
            child: isSelected
                ? Icon(
                    Icons.check,
                    color: ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                  )
                : null,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Palet Adı'),
                controller: _nameController,
              ),
              const SizedBox(height: 16),
              const Text('Ana Renk', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildColorGrid(_primary, (c) => setState(() => _primary = c)),
              const SizedBox(height: 16),
              const Text('Vurgu Rengi', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildColorGrid(_accent, (c) => setState(() => _accent = c)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = _nameController.text.trim();
            final newPalette = AppPalette(
              id: widget.initialPalette.id,
              name: name.isNotEmpty ? name : 'Özel Palet',
              primary: _primary,
              onPrimary: ThemeData.estimateBrightnessForColor(_primary) == Brightness.dark
                  ? Colors.white
                  : Colors.black,
              accent: _accent,
              onAccent: ThemeData.estimateBrightnessForColor(_accent) == Brightness.dark
                  ? Colors.white
                  : Colors.black,
            );
            Navigator.of(context).pop(newPalette);
          },
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}
