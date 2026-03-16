import 'package:flutter/material.dart';

/// TypingIndicator widget (T045, US3)
/// 
/// Displays "[Username] is typing..." with animated three-dot animation.
/// Supports multiple users typing simultaneously.
/// 
/// Features:
/// - Animated bouncing dots
/// - Multiple user display
/// - Smooth fade in/out transitions
/// - Optional custom styling

class TypingIndicator extends StatefulWidget {
  /// List of usernames currently typing
  final List<String> typingUsernames;
  
  /// Whether to show the indicator
  final bool showIndicator;
  
  /// Text style for the typing indicator
  final TextStyle? textStyle;
  
  /// Dot color
  final Color? dotColor;
  
  /// Animation duration for dots
  final Duration animationDuration;

  const TypingIndicator({
    Key? key,
    required this.typingUsernames,
    this.showIndicator = true,
    this.textStyle,
    this.dotColor,
    this.animationDuration = const Duration(milliseconds: 400),
  }) : super(key: key);

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late List<Animation<double>> _dotAnimations;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: widget.animationDuration * 3,
      vsync: this,
    )..repeat();

    _dotAnimations = List.generate(3, (index) {
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(
            index * 0.33,
            (index + 1) * 0.33,
            curve: Curves.easeInOut,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showIndicator || widget.typingUsernames.isEmpty) {
      return const SizedBox.shrink();
    }

    // Build display text
    String displayText;
    if (widget.typingUsernames.length == 1) {
      displayText = '${widget.typingUsernames[0]} is typing';
    } else if (widget.typingUsernames.length == 2) {
      displayText =
          '${widget.typingUsernames[0]} and ${widget.typingUsernames[1]} are typing';
    } else {
      displayText =
          '${widget.typingUsernames[0]} and ${widget.typingUsernames.length - 1} others are typing';
    }

    return AnimatedOpacity(
      opacity: widget.showIndicator ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayText,
              style: widget.textStyle ??
                  Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
            ),
            const SizedBox(width: 4),
            _AnimatedDots(
              animations: _dotAnimations,
              dotColor: widget.dotColor ?? Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated dots widget for typing indicator
class _AnimatedDots extends StatelessWidget {
  final List<Animation<double>> animations;
  final Color? dotColor;

  const _AnimatedDots({
    required this.animations,
    this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: animations[index],
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, -animations[index].value * 8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: dotColor ?? Colors.grey[400],
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
