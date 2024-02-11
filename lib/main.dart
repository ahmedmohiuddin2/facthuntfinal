import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(FactHunterApp());
}

class FactHunterApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FactHunter',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: FactCheckingScreen(
        googleFactCheckApiKey: 'AIzaSyATsHomCLk72tKFv2vchIXYr_7vrh6bQGo',
        newsApiKey: '34793c6af102414bbcc457e537562723',
        triviaApiKey: '61e47b5173msh8eb7c34384cbe8bp1f4a20jsn920864f6ac52',
        googleCustomSearchApiKey: 'AIzaSyCUbu6uSo5mxfA1KpLwLe7bcfxU5lpO8WQ',
        chatGptApiKey: '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',
      ),
    );
  }
}

class FactCheckingScreen extends StatefulWidget {
  final String googleFactCheckApiKey;
  final String newsApiKey;
  final String triviaApiKey;
  final String googleCustomSearchApiKey;
  final String chatGptApiKey;

  FactCheckingScreen({
    required this.googleFactCheckApiKey,
    required this.newsApiKey,
    required this.triviaApiKey,
    required this.googleCustomSearchApiKey,
    required this.chatGptApiKey,
  });

  @override
  _FactCheckingScreenState createState() => _FactCheckingScreenState();
}

class _FactCheckingScreenState extends State<FactCheckingScreen> {
  TextEditingController _textController = TextEditingController();
  bool _isChecking = false;
  String _result = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Fact Checking'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _textController,
                decoration: InputDecoration(
                  labelText: 'Enter text to fact-check',
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isChecking
                    ? null
                    : () {
                        _checkFact(_textController.text);
                      },
                child: _isChecking
                    ? CircularProgressIndicator()
                    : Text('Check Fact'),
              ),
              SizedBox(height: 20),
              _result.isNotEmpty
                  ? Text(
                      '$_result',
                      style: TextStyle(
                        fontSize: 20,
                        color: _result == 'Fake' ? Colors.red : Colors.green,
                      ),
                    )
                  : Container(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _checkFact(String userInput) async {
    setState(() {
      _isChecking = true;
      _result = ''; // Reset result when new fact-check starts
    });

    try {
      // Attempt to fetch data from Google Fact Check Tools API
      String googleFactCheckData = await _fetchGoogleFactCheckData(userInput);

      // If data is not available from Google Fact Check Tools API, try other APIs
      if (googleFactCheckData.isEmpty) {
        String googleCustomSearchData =
            await _fetchGoogleCustomSearchData(userInput);
        String newsApiData = await _fetchNewsApiData(userInput);
        String triviaApiData = await _fetchTriviaApiData();

        // Pass data to ChatGPT for further analysis
        await _passToChatGPT(
            userInput, googleCustomSearchData, newsApiData, triviaApiData);
      } else {
        // Pass data from Google Fact Check Tools API to ChatGPT for further analysis
        await _passToChatGPT(userInput, googleFactCheckData, '', '');
      }
    } catch (e) {
      print('Error: $e');
      setState(() {
        _isChecking = false;
        _result = 'Error';
      });
    }
  }

  Future<String> _fetchGoogleFactCheckData(String userInput) async {
    String googleFactCheckUrl =
        'https://factchecktools.googleapis.com/v1alpha1/claims:search?query=$userInput&key=${widget.googleFactCheckApiKey}';

    var googleFactCheckResponse = await http.get(Uri.parse(googleFactCheckUrl));
    if (googleFactCheckResponse.statusCode == 200) {
      return jsonDecode(googleFactCheckResponse.body).toString();
    } else {
      return '';
    }
  }

  Future<String> _fetchGoogleCustomSearchData(String userInput) async {
    String googleCustomSearchUrl =
        'https://www.googleapis.com/customsearch/v1?key=${widget.googleCustomSearchApiKey}&q=$userInput';

    var googleCustomSearchResponse =
        await http.get(Uri.parse(googleCustomSearchUrl));
    if (googleCustomSearchResponse.statusCode == 200) {
      return jsonDecode(googleCustomSearchResponse.body).toString();
    } else {
      return '';
    }
  }

  Future<String> _fetchNewsApiData(String userInput) async {
    String newsApiUrl =
        'https://newsapi.org/v2/everything?q=$userInput&apiKey=${widget.newsApiKey}';

    var newsApiResponse = await http.get(Uri.parse(newsApiUrl));
    if (newsApiResponse.statusCode == 200) {
      return jsonDecode(newsApiResponse.body).toString();
    } else {
      return '';
    }
  }

  Future<String> _fetchTriviaApiData() async {
    String triviaApiUrl =
        'https://trivia-by-api-ninjas.p.rapidapi.com/v1/trivia=easy&type=multiple';

    var triviaApiResponse = await http.get(Uri.parse(triviaApiUrl), headers: {
      'x-rapidapi-host': 'trivia-by-api-ninjas.p.rapidapi.com',
      'x-rapidapi-key': widget.triviaApiKey,
    });
    if (triviaApiResponse.statusCode == 200) {
      return jsonDecode(triviaApiResponse.body).toString();
    } else {
      return '';
    }
  }

  Future<void> _passToChatGPT(String userInput, String googleData,
      String newsData, String triviaData) async {
    try {
      final endpoint = 'https://api.openai.com/v1/chat/completions';

      final messages = [
        {'role': 'system', 'content': 'Prompt: $userInput'},
        {'role': 'system', 'content': 'Google Fact Check Data: $googleData'},
        {'role': 'system', 'content': 'News API Data: $newsData'},
        {'role': 'system', 'content': 'Trivia API Data: $triviaData'},
        {
          'role': 'user',
          'content': ''
        } // Empty user message to generate completion
      ];

      final chunkSize = 3; // Adjust chunk size as needed
      final chunkedMessages = <Map<String, dynamic>>[];
      for (var i = 0; i < messages.length; i += chunkSize) {
        final end =
            (i + chunkSize < messages.length) ? i + chunkSize : messages.length;
        final chunk = messages.sublist(i, end);
        chunkedMessages.add({'messages': chunk});
      }

      final responses = <String>[];
      for (var chunk in chunkedMessages) {
        final response = await http.post(
          Uri.parse(endpoint),
          headers: {
            'Authorization': 'Bearer ${widget.chatGptApiKey}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            ...chunk,
            'model': 'gpt-3.5-turbo-1106', // Use the latest chat model
            'max_tokens': 100, // Adjust max tokens as needed
            'temperature': 0.7, // Adjust temperature for response randomness
            'top_p': 1,
          }),
        );

        if (response.statusCode == 200) {
          responses.add(
              jsonDecode(response.body)['choices'][0]['message']['content']);
        } else {
          // Handle error response
          print(
              'Failed to interact with ChatGPT API. Status code: ${response.statusCode}, Body: ${response.body}');
          throw Exception('Failed to interact with ChatGPT API');
        }
      }

      final aggregatedResponse = responses.join();
      setState(() {
        _result = aggregatedResponse;
      });
    } catch (e) {
      // Log any exceptions that occur during the API call
      print('Error interacting with ChatGPT API: $e');
      setState(() {
        _isChecking = false;
        _result = 'Error';
      });
    } finally {
      // Reset _isChecking flag after API call completes
      setState(() {
        _isChecking = false;
      });
    }
  }
}
