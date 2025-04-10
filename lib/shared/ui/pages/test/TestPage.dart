import 'package:flutter/material.dart';
import 'package:whitebox/shared/ui/components/basic/StepperComponent.dart';

class StepperTestPage extends StatefulWidget {
  const StepperTestPage({super.key});

  @override
  State<StepperTestPage> createState() => _StepperTestPageState();
}

class _StepperTestPageState extends State<StepperTestPage> {
  // Toggle between different models for testing
  String currentModel = 'A';

  void _changeModel(String newModel) {
    setState(() {
      currentModel = newModel;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('Stepper Component Test'),
      //   backgroundColor: Colors.grey[200],
      // ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Model selection buttons
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Select Model: ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => _changeModel('A'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: currentModel == 'A' ? Colors.grey[400] : Colors.grey[300],
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(0),
                        side: BorderSide(color: Colors.grey[400]!),
                      ),
                    ),
                    child: const Text('Model A'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => _changeModel('B'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: currentModel == 'B' ? Colors.grey[400] : Colors.grey[300],
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(0),
                        side: BorderSide(color: Colors.grey[400]!),
                      ),
                    ),
                    child: const Text('Model B'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => _changeModel('C'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: currentModel == 'C' ? Colors.grey[400] : Colors.grey[300],
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(0),
                        side: BorderSide(color: Colors.grey[400]!),
                      ),
                    ),
                    child: const Text('Model C'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Display the current model being used
            Text(
              'Current Model: $currentModel',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 30),

            // StepperComponent with the selected model
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: StepperComponent(
                  configPath: 'lib/shared/config/flows/initialization/wifi.json',
                  modelType: currentModel,
                ),
              ),
            ),

            // Explanation text
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
              child: Text(
                'This test page allows you to switch between different models to see how the StepperComponent behaves with different configurations. Use the Previous and Next buttons in the StepperComponent to navigate between steps.',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}