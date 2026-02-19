require('dotenv').config();
const express = require('express');

const app = express();
const PORT = process.env.PORT || 8080;
const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
const GEMINI_MODEL = process.env.GEMINI_MODEL || 'gemini-1.5-flash';

// Middleware
app.use(express.json({ limit: '10mb' }));

// CORS - 允许所有来源（方便本地调试）
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') {
    return res.sendStatus(200);
  }
  next();
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    ok: true,
    hasApiKey: !!GEMINI_API_KEY
  });
});

// Main endpoint: POST /api/face-analysis
app.post('/api/face-analysis', async (req, res) => {
  try {
    const { face_analysis, image_base64 } = req.body;

    // 校验必需字段
    if (!face_analysis) {
      return res.status(400).json({
        message: '',
        error: 'Missing required field: face_analysis'
      });
    }

    // 检查 API Key
    if (!GEMINI_API_KEY) {
      console.error('GEMINI_API_KEY not configured in environment variables');
      return res.status(500).json({
        message: '',
        error: 'Server configuration error: GEMINI_API_KEY not set. Please configure it in .env file.'
      });
    }

    // 构建给模型的 prompt
    const prompt = buildPrompt(face_analysis);
    
    // 调用 Gemini API（generateContent）
    const geminiResponse = await fetch(
      // 使用 v1 端点以支持 gemini-1.5-flash 等当前模型
      `https://generativelanguage.googleapis.com/v1/models/${encodeURIComponent(GEMINI_MODEL)}:generateContent?key=${encodeURIComponent(GEMINI_API_KEY)}`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          // 直接把“语气/风格”指令写进用户 prompt，避免使用 system 字段带来的兼容性问题
          contents: [
            {
              role: 'user',
              parts: [
                {
                  text:
                    'You are a friendly AI assistant that provides brief, encouraging, and fun comments about facial expressions and expressions. ' +
                    'Keep responses to one short sentence (under 20 words). Be positive and playful.\n\n' +
                    prompt
                }
              ]
            }
          ],
          generation_config: {
            max_output_tokens: 50,
            temperature: 0.7
          }
        })
      }
    );

    if (!geminiResponse.ok) {
      const errorData = await geminiResponse.json().catch(() => ({}));
      console.error('Gemini API error:', errorData);
      return res.status(500).json({
        message: '',
        error: `Gemini API error: ${errorData.error?.message || 'Unknown error'}`
      });
    }

    const geminiData = await geminiResponse.json();

    const aiMessage =
      geminiData.candidates?.[0]?.content?.parts
        ?.map(p => p.text)
        .join(' ')
        .trim() || '';

    if (!aiMessage) {
      return res.status(500).json({
        message: '',
        error: 'Empty response from Gemini'
      });
    }

    // 返回成功响应
    res.json({
      message: aiMessage,
      error: null
    });

  } catch (error) {
    console.error('Server error:', error);
    res.status(500).json({
      message: '',
      error: `Internal server error: ${error.message}`
    });
  }
});

// 构建 prompt 的函数
function buildPrompt(faceAnalysis) {
  const {
    has_face,
    num_faces,
    blendshapes_top = [],
    landmark_stats = {},
    timestamp_ms
  } = faceAnalysis;

  if (!has_face || num_faces === 0) {
    return 'No face detected in the frame.';
  }

  let prompt = `I detected ${num_faces} face(s). `;

  // 添加 blendshapes 信息
  if (blendshapes_top && blendshapes_top.length > 0) {
    const topExpressions = blendshapes_top.slice(0, 3).map(b => b.name).join(', ');
    prompt += `Top expressions: ${topExpressions}. `;
  }

  // 添加 landmark stats
  if (landmark_stats) {
    const stats = [];
    
    if (landmark_stats.mouth_open !== undefined) {
      const mouthLevel = landmark_stats.mouth_open > 0.5 ? 'open' : 'closed';
      stats.push(`mouth ${mouthLevel}`);
    }
    
    if (landmark_stats.eye_blink_left !== undefined || landmark_stats.eye_blink_right !== undefined) {
      const leftBlink = landmark_stats.eye_blink_left > 0.5;
      const rightBlink = landmark_stats.eye_blink_right > 0.5;
      if (leftBlink || rightBlink) {
        stats.push('blinking');
      }
    }
    
    if (landmark_stats.eyebrow_raise !== undefined && landmark_stats.eyebrow_raise > 0.5) {
      stats.push('eyebrows raised');
    }
    
    if (landmark_stats.head_pose_yaw !== undefined || landmark_stats.head_pose_pitch !== undefined) {
      const yaw = Math.abs(landmark_stats.head_pose_yaw || 0);
      const pitch = Math.abs(landmark_stats.head_pose_pitch || 0);
      if (yaw > 15 || pitch > 15) {
        stats.push('head turned');
      }
    }
    
    if (stats.length > 0) {
      prompt += `Facial features: ${stats.join(', ')}. `;
    }
  }

  prompt += 'Give me a brief, fun comment about this expression.';

  return prompt;
}

// 启动服务器
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Bestie-Check Backend (Gemini) running on http://0.0.0.0:${PORT}`);
  console.log(`📡 Health check: http://localhost:${PORT}/health`);
  console.log(`🔑 Gemini API Key configured: ${GEMINI_API_KEY ? 'Yes' : 'No (please set GEMINI_API_KEY in .env)'}`);
});
