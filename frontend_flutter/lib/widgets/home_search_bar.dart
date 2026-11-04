import 'package:flutter/material.dart';

class HomeSearchBar extends StatefulWidget {
  const HomeSearchBar({super.key, this.onSearch, this.onTap});

  final ValueChanged<String>? onSearch;
  final VoidCallback? onTap;

  @override
  State<HomeSearchBar> createState() => _HomeSearchBarState();
}

class _HomeSearchBarState extends State<HomeSearchBar> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final query = _controller.text.trim();
    if (widget.onSearch != null) {
      widget.onSearch!(query);
    } else {
      widget.onTap?.call();
    }
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 52,
            padding: const EdgeInsets.only(left: 16, right: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFD9E5F2)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0B2545).withValues(alpha: .06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Color(0xFF0056B3)),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      hintText: 'Buscar doctores o clínicas',
                      hintStyle: TextStyle(color: Color(0xFF64748B)),
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Buscar',
                  onPressed: _submit,
                  icon: const Icon(Icons.arrow_forward_rounded,
                      color: Color(0xFF0056B3)),
                ),
              ],
            ),
          ),
        ),
      );
}
