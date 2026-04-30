require('dotenv').config();
const fs = require('fs');
const path = require('path');
const express = require('express');

const app = express();
const PORT = process.env.PORT || 8080;
const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
const GEMINI_MODEL = process.env.GEMINI_MODEL || 'gemini-1.5-flash';

const mainPromptPath = path.join(__dirname, 'main_prompt.txt');
const outputRulePath = path.join(__dirname, 'output_rule.txt');
const outputFormatPath = path.join(__dirname, 'output_format.txt');
let geminiStaticPrompt = '';

try {
  const mainPrompt = fs.readFileSync(mainPromptPath, 'utf8').trim();
  const outputRule = fs.readFileSync(outputRulePath, 'utf8').trim();
  const outputFormat = fs.readFileSync(outputFormatPath, 'utf8').trim();
  geminiStaticPrompt = [mainPrompt, outputRule, outputFormat].filter(Boolean).join('\n\n');
} catch (error) {
  console.error(`Failed to load Gemini prompt files from ${mainPromptPath} and ${outputRulePath}:`, error);
  process.exit(1);
}

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

    // 构建给模型的 prompt（结构化数据摘要）
    const textPart = `${geminiStaticPrompt}

    Image / face analysis data:
    ${buildPrompt(face_analysis)}`;
    // 组装 user parts：先文字，若有图则加 inline_data（多模态）
    const userParts = [{ text: textPart }];
    if (image_base64 && typeof image_base64 === 'string' && image_base64.length > 0) {
      userParts.push({
        inline_data: {
          mime_type: 'image/jpeg',
          data: image_base64.replace(/^data:image\/\w+;base64,/, '')
        }
      });
    }

    const geminiResponse = await fetch(
      `https://generativelanguage.googleapis.com/v1/models/${encodeURIComponent(GEMINI_MODEL)}:generateContent?key=${encodeURIComponent(GEMINI_API_KEY)}`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          contents: [
            {
              role: 'user',
              parts: userParts
            }
          ],
          generation_config: {
            max_output_tokens: 300,
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

  prompt += 'Use the image and this face-analysis data only as supporting context. Generate makeup feedback according to the system instructions above.';

  return prompt;
}

// 启动服务器
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Bestie-Check Backend (Gemini) running on http://0.0.0.0:${PORT}`);
  console.log(`📡 Health check: http://localhost:${PORT}/health`);
  console.log(`🔑 Gemini API Key configured: ${GEMINI_API_KEY ? 'Yes' : 'No (please set GEMINI_API_KEY in .env)'}`);
});
