class AssessmentQuestion {
  final int id;
  final String question;
  final String type;
  final List<String>? options;
  final int? min;
  final int? max;
  final String category;

  AssessmentQuestion({
    required this.id,
    required this.question,
    required this.type,
    this.options,
    this.min,
    this.max,
    required this.category,
  });

  factory AssessmentQuestion.fromJson(Map<String, dynamic> json) {
    return AssessmentQuestion(
      id: json['id'],
      question: json['question'],
      type: json['type'],
      options: json['options'] != null ? List<String>.from(json['options']) : null,
      min: json['min'],
      max: json['max'],
      category: json['category'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'type': type,
      'options': options,
      'min': min,
      'max': max,
      'category': category,
    };
  }
}

class AssessmentResponse {
  final int questionId;
  final String question;
  final String type;
  final List<String>? options;
  final int? min;
  final int? max;
  final String category;
  final String? answer;

  AssessmentResponse({
    required this.questionId,
    required this.question,
    required this.type,
    this.options,
    this.min,
    this.max,
    required this.category,
    this.answer,
  });

  factory AssessmentResponse.fromJson(Map<String, dynamic> json) {
    return AssessmentResponse(
      questionId: json['questionId'],
      question: json['question'],
      type: json['type'],
      options: json['options'] != null ? List<String>.from(json['options']) : null,
      min: json['min'],
      max: json['max'],
      category: json['category'],
      answer: json['answer'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'questionId': questionId,
      'question': question,
      'type': type,
      'options': options,
      'min': min,
      'max': max,
      'category': category,
      'answer': answer,
    };
  }
}

class AssessmentResult {
  final int assessmentId;
  final double score;
  final String feedback;
  final String timestamp;

  AssessmentResult({
    required this.assessmentId,
    required this.score,
    required this.feedback,
    required this.timestamp,
  });

  factory AssessmentResult.fromJson(Map<String, dynamic> json) {
    return AssessmentResult(
      assessmentId: json['assessment_id'],
      score: json['score']?.toDouble() ?? 0.0,
      feedback: json['feedback'] ?? '',
      timestamp: json['timestamp'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'assessment_id': assessmentId,
      'score': score,
      'feedback': feedback,
      'timestamp': timestamp,
    };
  }
} 