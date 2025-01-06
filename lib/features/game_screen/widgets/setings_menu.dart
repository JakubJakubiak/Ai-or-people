import 'package:flutter/material.dart';
import 'package:humanai/features/game_screen/streak_service.dart';
import 'package:humanai/features/game_screen/widgets/daily_raking.dart';

class SettingsMenu extends StatefulWidget {
  final int score;
  final Function(String) onOptionChanged;

  const SettingsMenu({
    super.key,
    required this.score,
    required this.onOptionChanged,
  });

  @override
  State<SettingsMenu> createState() => _SettingsMenuState();
}

class _SettingsMenuState extends State<SettingsMenu> {
  final Set<String> _selectedOptions = {'text'}; // Default option
  final List<Set<String>> _history = [
    {'text'}
  ]; // History of states

  void _toggleOption(String option) {
    setState(() {
      Set<String> newSelection = Set.from(_selectedOptions);

      if (newSelection.contains(option)) {
        if (newSelection.length > 1) {
          newSelection.remove(option);
        }
      } else {
        newSelection.add(option);
      }

      _history.add(Set.from(_selectedOptions));
      _selectedOptions.clear();
      _selectedOptions.addAll(newSelection);

      widget.onOptionChanged(option);
    });
  }

  void _undo() {
    if (_history.isNotEmpty) {
      setState(() {
        _selectedOptions.clear();
        _selectedOptions.addAll(_history.last);
        _history.removeLast();
      });
    }
  }

  Future<bool> _onWillPop() async {
    _undo();
    return _history.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // onWillPop: _onWillPop,
      child: AlertDialog(
        title: const Text('Settings'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              // Wrap(
              //   alignment: WrapAlignment.center,
              //   spacing: 8,
              //   runSpacing: 8,
              //   children: [
              //     _OptionButton(
              //       label: 'Text',
              //       isSelected: _selectedOptions.contains('text'),
              //       onPressed: () => _toggleOption('text'),
              //     ),
              //     _OptionButton(
              //       label: 'Music',
              //       isSelected: _selectedOptions.contains('music'),
              //       onPressed: () => _toggleOption('music'),
              //     ),
              //   ],
              // ),
              // const SizedBox(height: 8),
              // Wrap(
              //   alignment: WrapAlignment.center,
              //   spacing: 8,
              //   runSpacing: 8,
              //   children: [
              //     _OptionButton(
              //       label: 'Books',
              //       isSelected: _selectedOptions.contains('books'),
              //       onPressed: () => _toggleOption('books'),
              //     ),
              //     _OptionButton(
              //       label: 'Video',
              //       isSelected: _selectedOptions.contains('video'),
              //       onPressed: () => _toggleOption('video'),
              //     ),
              //   ],
              // ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ElevatedButton.icon(
                  //   onPressed: _history.isNotEmpty ? _undo : null,
                  //   icon: const Icon(Icons.undo),
                  //   label: const Text('Undo'),
                  //   style: ElevatedButton.styleFrom(
                  //     backgroundColor: _history.isNotEmpty ? Theme.of(context).primaryColor : Colors.grey,
                  //   ),
                  // ),
                  const SizedBox(width: 20),
                  ElevatedButton(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        // backgroundColor: Colors.transparent,
                        builder: (context) => SlidingMenuWidget(
                          consecutiveDays: StreakService.instance.getCurrentStreak(),
                          onClose: () => Navigator.pop(context),
                        ),
                      );
                    },
                    child: const Text('Show days'),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  const _OptionButton({
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120, // Fixed width for consistency
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? Theme.of(context).primaryColor : Colors.grey,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
}
