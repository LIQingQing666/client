import crypto from 'node:crypto';
import { v4 as uuid } from 'uuid';
import { getDb, initDb } from './schema.js';

function hashPassword(password: string): string {
  const salt = crypto.randomBytes(16).toString('hex');
  const hash = crypto.pbkdf2Sync(password, salt, 100000, 64, 'sha512').toString('hex');
  return `${salt}:${hash}`;
}

interface VideoSeed {
  title: string;
  description: string;
  cover_url: string;
  video_url: string;
  author_id: string;
  author_name: string;
  author_avatar: string;
  duration: number;
  tags: string;
  like_count: number;
  comment_count: number;
  share_count: number;
  play_count: number;
}

interface ProductSeed {
  name: string;
  description: string;
  cover_url: string;
  images: string;
  price: number;
  original_price: number;
  stock: number;
  sales: number;
  category: string;
  tags: string;
  specs: string;
  video_id: string;
  ai_sales_point: string;
  highlight_time: number;
}

function seed() {
  const db = getDb();
  initDb();

  // Clean existing data
  db.exec('DELETE FROM customer_service_messages');
  db.exec('DELETE FROM refund_records');
  db.exec('DELETE FROM recharge_records');
  // 直播相关（必须在 products / users 之前清理，因为有 FK）
  db.exec('DELETE FROM live_view_history');
  db.exec('DELETE FROM gift_records');
  db.exec('DELETE FROM live_interactions');
  db.exec('DELETE FROM live_messages');
  db.exec('DELETE FROM live_rooms');
  db.exec('DELETE FROM gifts');
  db.exec('DELETE FROM user_likes');
  db.exec('DELETE FROM user_coupons');
  db.exec('DELETE FROM comments');
  db.exec('DELETE FROM follows');
  db.exec('DELETE FROM orders');
  db.exec('DELETE FROM cart_items');
  db.exec('DELETE FROM products');
  db.exec('DELETE FROM videos');
  db.exec('DELETE FROM coupons');
  db.exec('DELETE FROM users');

  // ---- Users ----
  const defaultHash = hashPassword('123456');
  const users = [
    { id: 'u1', nickname: '测试用户', avatar: '', phone: '13800000001', password: defaultHash, role: 'user' },
    { id: 'u2', nickname: '小明数码', avatar: '', phone: '', password: defaultHash, role: 'merchant' },
    { id: 'u3', nickname: '小红穿搭', avatar: '', phone: '', password: defaultHash, role: 'merchant' },
    { id: 'u4', nickname: '阿杰户外', avatar: '', phone: '', password: defaultHash, role: 'merchant' },
    { id: 'u5', nickname: '数码控小王', avatar: '', phone: '', password: defaultHash, role: 'merchant' },
  ];

  // Add coin_balance column if not exists (migration for existing databases)
  db.exec("SELECT CASE WHEN COUNT(*) = 0 THEN 0 ELSE 1 END FROM pragma_table_info('users') WHERE name='coin_balance'");
  try {
    db.exec("ALTER TABLE users ADD COLUMN coin_balance REAL NOT NULL DEFAULT 0");
  } catch (_) {
    // Column already exists, ignore
  }

  const insertUser = db.prepare(
    'INSERT INTO users (id, nickname, avatar, phone, password, role, coin_balance) VALUES (@id, @nickname, @avatar, @phone, @password, @role, @coin_balance)'
  );
  for (const u of users) {
    insertUser.run({ ...u, coin_balance: 0 });
  }

  // ---- Videos (10) ----
  const authorIds = ['u2', 'u3', 'u4', 'u5'];
  const videoIds: string[] = [];
  const videos: VideoSeed[] = [
    {
      title: '2024新款TWS降噪耳机深度体验',
      description: '这款耳机降噪效果超乎想象，续航长达30小时，佩戴舒适，是通勤和办公的最佳选择。',
      cover_url: 'https://picsum.photos/seed/v1/400/600',
      video_url: 'http://192.168.50.174:3000/uploads/videos/butterfly.mp4',
      author_id: 'u2',
      author_name: '小明数码',
      author_avatar: '',
      duration: 45,
      tags: '["数码","耳机","降噪"]',
      like_count: 3200,
      comment_count: 156,
      share_count: 89,
      play_count: 56000,
    },
    {
      title: '显瘦百搭！春季新款连衣裙开箱',
      description: '这件连衣裙面料柔软亲肤，版型超正，小个子也能驾驭，三色可选性价比很高！',
      cover_url: 'https://picsum.photos/seed/v2/400/600',
      video_url: 'http://192.168.50.174:3000/uploads/videos/video2.mp4',
      author_id: 'u3',
      author_name: '小红穿搭',
      author_avatar: '',
      duration: 60,
      tags: '["穿搭","连衣裙","春季"]',
      like_count: 8900,
      comment_count: 432,
      share_count: 256,
      play_count: 123000,
    },
    {
      title: '懒人必备！智能扫地机器人实测',
      description: '激光导航精准建图，5000Pa大吸力，自动集尘，真正解放双手的清洁神器。',
      cover_url: 'https://picsum.photos/seed/v3/400/600',
      video_url: 'http://192.168.50.174:3000/uploads/videos/video3.mp4',
      author_id: 'u2',
      author_name: '小明数码',
      author_avatar: '',
      duration: 55,
      tags: '["数码","扫地机器人","智能家居"]',
      like_count: 5600,
      comment_count: 289,
      share_count: 145,
      play_count: 89000,
    },
    {
      title: '学生党平价护肤好物推荐',
      description: '百元以内的宝藏护肤品，成分安全有效，适合学生党和护肤新手，性价比天花板！',
      cover_url: 'https://picsum.photos/seed/v4/400/600',
      video_url: 'http://192.168.50.174:3000/uploads/videos/butterfly.mp4',
      author_id: 'u3',
      author_name: '小红穿搭',
      author_avatar: '',
      duration: 50,
      tags: '["护肤","学生党","平价"]',
      like_count: 12000,
      comment_count: 678,
      share_count: 412,
      play_count: 210000,
    },
    {
      title: '户外露营装备开箱｜新手入门套装',
      description: '帐篷、睡袋、炉具一整套不到500元，新手露营完全够了，周末出去走走吧！',
      cover_url: 'https://picsum.photos/seed/v5/400/600',
      video_url: 'http://192.168.50.174:3000/uploads/videos/video2.mp4',
      author_id: 'u4',
      author_name: '阿杰户外',
      author_avatar: '',
      duration: 72,
      tags: '["户外","露营","装备"]',
      like_count: 4500,
      comment_count: 198,
      share_count: 167,
      play_count: 67000,
    },
    {
      title: '打工人必备！人体工学椅深度评测',
      description: '久坐不累的秘诀，腰靠可调节，网面透气，千元价位最能打的人体工学椅。',
      cover_url: 'https://picsum.photos/seed/v6/400/600',
      video_url: 'http://192.168.50.174:3000/uploads/videos/video3.mp4',
      author_id: 'u5',
      author_name: '数码控小王',
      author_avatar: '',
      duration: 68,
      tags: '["数码","办公","人体工学椅"]',
      like_count: 7800,
      comment_count: 345,
      share_count: 234,
      play_count: 98000,
    },
    {
      title: '减脂餐这样做好吃又掉秤',
      description: '一周不重样的减脂餐食谱，低卡高蛋白，做法简单，吃饱也能瘦！',
      cover_url: 'https://picsum.photos/seed/v7/400/600',
      video_url: 'http://192.168.50.174:3000/uploads/videos/butterfly.mp4',
      author_id: 'u4',
      author_name: '阿杰户外',
      author_avatar: '',
      duration: 40,
      tags: '["美食","减脂","健康"]',
      like_count: 15000,
      comment_count: 890,
      share_count: 567,
      play_count: 256000,
    },
    {
      title: '苹果安卓都能用的磁吸充电宝',
      description: '10000mAh大容量，支持MagSafe磁吸，20W快充，出门再也不用带线。',
      cover_url: 'https://picsum.photos/seed/v8/400/600',
      video_url: 'http://192.168.50.174:3000/uploads/videos/video2.mp4',
      author_id: 'u2',
      author_name: '小明数码',
      author_avatar: '',
      duration: 42,
      tags: '["数码","充电宝","磁吸"]',
      like_count: 6200,
      comment_count: 312,
      share_count: 178,
      play_count: 78000,
    },
    {
      title: '宠物体检必做项目清单｜养宠新手必看',
      description: '新猫新狗到家第一件事就是体检，这些项目一定要做，能省下好多医药费。',
      cover_url: 'https://picsum.photos/seed/v9/400/600',
      video_url: 'http://192.168.50.174:3000/uploads/videos/video3.mp4',
      author_id: 'u5',
      author_name: '数码控小王',
      author_avatar: '',
      duration: 58,
      tags: '["宠物","养宠","体检"]',
      like_count: 3400,
      comment_count: 234,
      share_count: 98,
      play_count: 45000,
    },
    {
      title: '年末大扫除！这些清洁神器太好用了',
      description: '玻璃刮、除霉剂、静电拖把……这些都是我家无限回购的清洁好物，省时省力。',
      cover_url: 'https://picsum.photos/seed/v10/400/600',
      video_url: 'http://192.168.50.174:3000/uploads/videos/butterfly.mp4',
      author_id: 'u3',
      author_name: '小红穿搭',
      author_avatar: '',
      duration: 65,
      tags: '["家居","清洁","好物"]',
      like_count: 9800,
      comment_count: 456,
      share_count: 345,
      play_count: 145000,
    },
  ];

  const insertVideo = db.prepare(
    `INSERT INTO videos (id, title, description, cover_url, video_url, author_id, author_name, author_avatar, duration, tags, like_count, comment_count, share_count, play_count)
     VALUES (@id, @title, @description, @cover_url, @video_url, @author_id, @author_name, @author_avatar, @duration, @tags, @like_count, @comment_count, @share_count, @play_count)`
  );
  for (const v of videos) {
    const id = uuid();
    videoIds.push(id);
    insertVideo.run({ id, ...v });
  }

  // ---- Products (20) ----
  const products: ProductSeed[] = [
    {
      name: 'TWS降噪蓝牙耳机 Pro',
      description: 'ANC主动降噪，-35dB深度降噪，蓝牙5.3稳定连接，30小时超长续航，IPX5防水，Type-C快充。',
      cover_url: 'https://picsum.photos/seed/p1/400/400',
      images: '["https://picsum.photos/seed/p1a/400/400","https://picsum.photos/seed/p1b/400/400"]',
      price: 299,
      original_price: 599,
      stock: 500,
      sales: 3200,
      category: '数码',
      tags: '["耳机","降噪","蓝牙"]',
      specs: '[{"name":"颜色","values":["黑色","白色","蓝色"]}]',
      video_id: videoIds[0],
      ai_sales_point: 'ANC主动降噪+30小时续航，通勤党闭眼入，性价比碾压千元耳机！',
      highlight_time: 3,
    },
    {
      name: '春季新款法式连衣裙',
      description: '雪纺面料，轻盈飘逸，收腰设计显瘦，适合日常通勤和约会穿搭。',
      cover_url: 'https://picsum.photos/seed/p2/400/400',
      images: '["https://picsum.photos/seed/p2a/400/400"]',
      price: 169,
      original_price: 399,
      stock: 200,
      sales: 5600,
      category: '服饰',
      tags: '["连衣裙","春季","法式"]',
      specs: '[{"name":"尺码","values":["S","M","L","XL"]},{"name":"颜色","values":["米白","浅蓝","粉色"]}]',
      video_id: videoIds[1],
      ai_sales_point: '法式收腰设计显瘦又优雅，三色可选，春天穿上它温柔加倍！',
      highlight_time: 5,
    },
    {
      name: '智能扫地机器人 S10',
      description: 'LDS激光导航，5000Pa飓风吸力，自动集尘30天免清理，支持米家/天猫精灵控制。',
      cover_url: 'https://picsum.photos/seed/p3/400/400',
      images: '["https://picsum.photos/seed/p3a/400/400"]',
      price: 1299,
      original_price: 2499,
      stock: 150,
      sales: 2100,
      category: '数码',
      tags: '["扫地机器人","智能家居","清洁"]',
      specs: '[{"name":"版本","values":["标准版","集尘版"]}]',
      video_id: videoIds[2],
      ai_sales_point: '激光导航+5000Pa吸力，30天免倒垃圾，打工人真正的解放双手神器！',
      highlight_time: 2,
    },
    {
      name: '氨基酸洁面泡沫 150ml',
      description: '温和氨基酸配方，不紧绷不假滑，适合所有肤质，敏感肌可用。',
      cover_url: 'https://picsum.photos/seed/p4/400/400',
      images: '["https://picsum.photos/seed/p4a/400/400"]',
      price: 59,
      original_price: 129,
      stock: 800,
      sales: 12000,
      category: '美妆',
      tags: '["洁面","氨基酸","敏感肌"]',
      specs: '[]',
      video_id: videoIds[3],
      ai_sales_point: '氨基酸配方温和不刺激，敏感肌闭眼入，学生党必囤！',
      highlight_time: 4,
    },
    {
      name: '户外双人帐篷 防风防雨',
      description: '3秒速开，双层防风防雨，UPF50+防晒，适合春夏秋三季露营。',
      cover_url: 'https://picsum.photos/seed/p5/400/400',
      images: '["https://picsum.photos/seed/p5a/400/400"]',
      price: 199,
      original_price: 459,
      stock: 300,
      sales: 1800,
      category: '户外',
      tags: '["帐篷","露营","户外"]',
      specs: '[{"name":"颜色","values":["军绿","橙色","蓝色"]}]',
      video_id: videoIds[4],
      ai_sales_point: '3秒速开新手友好，防风防雨还防晒，周末露营走起！',
      highlight_time: 6,
    },
    {
      name: '人体工学办公椅 Pro',
      description: '4D可调扶手，135°后仰，独立腰靠，进口网布透气耐磨，承重150kg。',
      cover_url: 'https://picsum.photos/seed/p6/400/400',
      images: '["https://picsum.photos/seed/p6a/400/400"]',
      price: 899,
      original_price: 1899,
      stock: 100,
      sales: 3400,
      category: '家居',
      tags: '["办公椅","人体工学","久坐"]',
      specs: '[{"name":"颜色","values":["黑色","灰色"]}]',
      video_id: videoIds[5],
      ai_sales_point: '腰靠4D可调+透气网面，千元内久坐不累的天花板，打工人腰椎救星！',
      highlight_time: 1,
    },
    {
      name: '低脂高蛋白鸡胸肉 10袋装',
      description: '即食调味鸡胸肉，每100g仅118大卡，高蛋白低脂肪，健身减脂必备。',
      cover_url: 'https://picsum.photos/seed/p7/400/400',
      images: '["https://picsum.photos/seed/p7a/400/400"]',
      price: 49.9,
      original_price: 89,
      stock: 1000,
      sales: 25000,
      category: '食品',
      tags: '["鸡胸肉","减脂","高蛋白"]',
      specs: '[{"name":"口味","values":["原味","黑椒","奥尔良","香辣"]}]',
      video_id: videoIds[6],
      ai_sales_point: '低卡高蛋白即食鸡胸肉，四种口味不重样，减脂期也能吃得开心！',
      highlight_time: 3,
    },
    {
      name: '磁吸无线充电宝 10000mAh',
      description: 'MagSafe磁吸充电宝，15W无线快充+20W有线，LED电量显示，超薄便携。',
      cover_url: 'https://picsum.photos/seed/p8/400/400',
      images: '["https://picsum.photos/seed/p8a/400/400"]',
      price: 139,
      original_price: 299,
      stock: 400,
      sales: 7800,
      category: '数码',
      tags: '["充电宝","磁吸","无线充电"]',
      specs: '[{"name":"颜色","values":["黑色","白色","紫色"]}]',
      video_id: videoIds[7],
      ai_sales_point: 'MagSafe磁吸即贴即充，10000mAh超薄便携，出行告别充电线！',
      highlight_time: 5,
    },
    {
      name: '宠物驱虫套餐 内外同驱',
      description: '猫咪狗狗通用体内外驱虫，3个月用量，安全有效，大宠爱同款成分。',
      cover_url: 'https://picsum.photos/seed/p9/400/400',
      images: '["https://picsum.photos/seed/p9a/400/400"]',
      price: 89,
      original_price: 189,
      stock: 600,
      sales: 4200,
      category: '宠物',
      tags: '["驱虫","宠物","猫咪","狗狗"]',
      specs: '[{"name":"适用","values":["猫咪专用","狗狗专用","通用型"]}]',
      video_id: videoIds[8],
      ai_sales_point: '大宠爱同款成分内外同驱，三个月用量只要89元，毛孩子健康必备！',
      highlight_time: 2,
    },
    {
      name: '多功能清洁套装 5件套',
      description: '玻璃刮、除霉剂、静电拖把、纳米海绵、水垢清洁剂，全屋清洁一站搞定。',
      cover_url: 'https://picsum.photos/seed/p10/400/400',
      images: '["https://picsum.photos/seed/p10a/400/400"]',
      price: 79,
      original_price: 169,
      stock: 350,
      sales: 8900,
      category: '家居',
      tags: '["清洁","家居","必备"]',
      specs: '[]',
      video_id: videoIds[9],
      ai_sales_point: '五件套一站式搞定全屋清洁，玻璃、霉菌、水垢统统消灭！',
      highlight_time: 4,
    },
    // Additional 10 products
    {
      name: '便携蓝牙音箱 防水款',
      description: 'IPX7级防水，20W大功率，12小时续航，支持TWS串联立体声。',
      cover_url: 'https://picsum.photos/seed/p11/400/400',
      images: '[]',
      price: 199,
      original_price: 399,
      stock: 250,
      sales: 4300,
      category: '数码',
      tags: '["蓝牙音箱","防水","户外"]',
      specs: '[{"name":"颜色","values":["黑色","蓝色","红色"]}]',
      video_id: '',
      ai_sales_point: 'IPX7防水+20W大功率，露营派对必备，音质对得起这个价！',
      highlight_time: 0,
    },
    {
      name: '男士休闲运动鞋 透气飞织',
      description: '飞织鞋面透气不闷脚，MD减震大底，轻便舒适适合日常运动和通勤。',
      cover_url: 'https://picsum.photos/seed/p12/400/400',
      images: '[]',
      price: 159,
      original_price: 359,
      stock: 400,
      sales: 6700,
      category: '服饰',
      tags: '["运动鞋","男鞋","透气"]',
      specs: '[{"name":"尺码","values":["39","40","41","42","43","44"]}]',
      video_id: '',
      ai_sales_point: '飞织鞋面透气到像没穿，超轻MD大底，通勤运动两不误！',
      highlight_time: 0,
    },
    {
      name: 'VC亮肤精华液 30ml',
      description: '10%原型VC+VE+阿魏酸，抗氧化提亮肤色，早晚可用。',
      cover_url: 'https://picsum.photos/seed/p13/400/400',
      images: '[]',
      price: 89,
      original_price: 199,
      stock: 500,
      sales: 9800,
      category: '美妆',
      tags: '["精华","美白","抗氧化"]',
      specs: '[]',
      video_id: '',
      ai_sales_point: '10%原型VC黄金浓度，提亮肤色肉眼可见，黄皮星人冲！',
      highlight_time: 0,
    },
    {
      name: '便携折叠露营椅',
      description: '铝合金骨架仅重1.2kg，承重150kg，带杯架和收纳袋，一秒收纳。',
      cover_url: 'https://picsum.photos/seed/p14/400/400',
      images: '[]',
      price: 89,
      original_price: 199,
      stock: 450,
      sales: 3200,
      category: '户外',
      tags: '["露营","椅子","折叠"]',
      specs: '[{"name":"颜色","values":["黑色","卡其色","军绿色"]}]',
      video_id: '',
      ai_sales_point: '1.2kg铝合金骨架超轻便携，一秒收纳不占地，露营人手一把！',
      highlight_time: 0,
    },
    {
      name: '记忆棉腰靠 办公室腰垫',
      description: '慢回弹记忆棉，3D立体支撑，可调节绑带，适用所有椅子。',
      cover_url: 'https://picsum.photos/seed/p15/400/400',
      images: '[]',
      price: 69,
      original_price: 149,
      stock: 600,
      sales: 12300,
      category: '家居',
      tags: '["腰靠","办公","记忆棉"]',
      specs: '[]',
      video_id: '',
      ai_sales_point: '慢回弹记忆棉3D环绕支撑，久坐党的续命神器，几十块保腰椎！',
      highlight_time: 0,
    },
    {
      name: '坚果混合装 每日坚果 30袋',
      description: '7种坚果果干科学配比，独立小包装，每日一袋补充营养。',
      cover_url: 'https://picsum.photos/seed/p16/400/400',
      images: '[]',
      price: 69.9,
      original_price: 139,
      stock: 800,
      sales: 21000,
      category: '食品',
      tags: '["坚果","健康","零食"]',
      specs: '[]',
      video_id: '',
      ai_sales_point: '7种坚果科学配比，一天一袋补充优质脂肪，健康零食首选！',
      highlight_time: 0,
    },
    {
      name: 'Type-C扩展坞 7合1',
      description: 'HDMI 4K@60Hz、USB3.0x3、SD/TF卡槽、PD100W快充，轻薄本必备。',
      cover_url: 'https://picsum.photos/seed/p17/400/400',
      images: '[]',
      price: 129,
      original_price: 299,
      stock: 350,
      sales: 5600,
      category: '数码',
      tags: '["扩展坞","Type-C","办公"]',
      specs: '[]',
      video_id: '',
      ai_sales_point: '7合1接口全覆盖，4K投屏+100W快充，轻薄本党闭眼入！',
      highlight_time: 0,
    },
    {
      name: '猫咪自动饮水机 2L',
      description: '循环过滤水质，静音水泵，2L大容量，USB供电，猫咪更爱喝水。',
      cover_url: 'https://picsum.photos/seed/p18/400/400',
      images: '[]',
      price: 69,
      original_price: 159,
      stock: 300,
      sales: 7800,
      category: '宠物',
      tags: '["饮水机","猫咪","宠物用品"]',
      specs: '[]',
      video_id: '',
      ai_sales_point: '循环活水吸引猫咪多喝水，预防泌尿疾病，铲屎官必备好物！',
      highlight_time: 0,
    },
    {
      name: '真空封口机 家用食品保鲜',
      description: '一键真空封口，干湿两用，延长食物保鲜期3-5倍，附赠10个真空袋。',
      cover_url: 'https://picsum.photos/seed/p19/400/400',
      images: '[]',
      price: 99,
      original_price: 229,
      stock: 200,
      sales: 4500,
      category: '家居',
      tags: '["封口机","保鲜","厨房"]',
      specs: '[]',
      video_id: '',
      ai_sales_point: '一键真空延长保鲜5倍，囤货党刚需，从此告别食材浪费！',
      highlight_time: 0,
    },
    {
      name: '瑜伽垫 加厚防滑 NBR材质',
      description: '10mm加厚NBR材质，双面防滑纹理，附赠收纳绑带，健身瑜伽通用。',
      cover_url: 'https://picsum.photos/seed/p20/400/400',
      images: '[]',
      price: 49,
      original_price: 109,
      stock: 700,
      sales: 16500,
      category: '运动',
      tags: '["瑜伽垫","健身","防滑"]',
      specs: '[{"name":"颜色","values":["紫色","蓝色","粉色","灰色"]}]',
      video_id: '',
      ai_sales_point: '10mm加厚NBR舒适不硌膝盖，双面防滑，居家健身必备！',
      highlight_time: 0,
    },
  ];

  const insertProduct = db.prepare(
    `INSERT INTO products (id, name, description, cover_url, images, price, original_price, stock, sales, category, tags, specs, video_id, ai_sales_point, highlight_time)
     VALUES (@id, @name, @description, @cover_url, @images, @price, @original_price, @stock, @sales, @category, @tags, @specs, @video_id, @ai_sales_point, @highlight_time)`
  );
  for (const p of products) {
    insertProduct.run({ id: uuid(), ...p });
  }

  // ---- Coupons ----
  const insertCoupon = db.prepare(
    `INSERT INTO coupons (id, title, amount, min_order, total_count, used_count, start_time, end_time)
     VALUES (@id, @title, @amount, @min_order, @total_count, @used_count, @start_time, @end_time)`
  );
  insertCoupon.run({
    id: uuid(),
    title: '新人满100减20',
    amount: 20,
    min_order: 100,
    total_count: 1000,
    used_count: 0,
    start_time: '2025-01-01T00:00:00Z',
    end_time: '2025-12-31T23:59:59Z',
  });
  insertCoupon.run({
    id: uuid(),
    title: '直播间限时满200减50',
    amount: 50,
    min_order: 200,
    total_count: 500,
    used_count: 0,
    start_time: '2025-01-01T00:00:00Z',
    end_time: '2025-12-31T23:59:59Z',
  });

  // ---- Cart Items (for user u1) ----
  const insertCartItem = db.prepare(
    `INSERT INTO cart_items (id, user_id, product_id, spec, quantity, selected)
     VALUES (@id, @user_id, @product_id, @spec, @quantity, @selected)`
  );
  const allProductIds = db
    .prepare('SELECT id FROM products LIMIT 3')
    .all() as Array<{ id: string }>;
  if (allProductIds.length >= 3) {
    insertCartItem.run({
      id: uuid(),
      user_id: 'u1',
      product_id: allProductIds[0].id,
      spec: '黑色',
      quantity: 1,
      selected: 1,
    });
    insertCartItem.run({
      id: uuid(),
      user_id: 'u1',
      product_id: allProductIds[1].id,
      spec: 'M',
      quantity: 2,
      selected: 1,
    });
    insertCartItem.run({
      id: uuid(),
      user_id: 'u1',
      product_id: allProductIds[2].id,
      spec: '标准版',
      quantity: 1,
      selected: 1,
    });
  }

  // ---- Orders (for user u1) ----
  const insertOrder = db.prepare(
    `INSERT INTO orders (id, user_id, total_amount, discount_amount, pay_amount, status, address, items)
     VALUES (@id, @user_id, @total_amount, @discount_amount, @pay_amount, @status, @address, @items)`
  );
  const first3Products = db
    .prepare('SELECT id, name, cover_url, price FROM products LIMIT 3')
    .all() as Array<{ id: string; name: string; cover_url: string; price: number }>;
  if (first3Products.length >= 3) {
    const addr = JSON.stringify({
      name: '张三',
      phone: '13800000001',
      detail: '北京市朝阳区望京SOHO T1 10层',
    });
    // Order 1: paid
    insertOrder.run({
      id: uuid(),
      user_id: 'u1',
      total_amount: 627,
      discount_amount: 0,
      pay_amount: 627,
      status: 'paid',
      address: addr,
      items: JSON.stringify([
        {
          product_id: first3Products[0].id,
          product_name: first3Products[0].name,
          product_cover: first3Products[0].cover_url,
          product_price: first3Products[0].price,
          spec: '黑色',
          quantity: 1,
          subtotal: first3Products[0].price,
        },
        {
          product_id: first3Products[1].id,
          product_name: first3Products[1].name,
          product_cover: first3Products[1].cover_url,
          product_price: first3Products[1].price,
          spec: 'M',
          quantity: 2,
          subtotal: first3Products[1].price * 2,
        },
      ]),
    });
    // Order 2: pending
    insertOrder.run({
      id: uuid(),
      user_id: 'u1',
      total_amount: 1299,
      discount_amount: 0,
      pay_amount: 1299,
      status: 'pending',
      address: addr,
      items: JSON.stringify([
        {
          product_id: first3Products[2].id,
          product_name: first3Products[2].name,
          product_cover: first3Products[2].cover_url,
          product_price: first3Products[2].price,
          spec: '标准版',
          quantity: 1,
          subtotal: first3Products[2].price,
        },
      ]),
    });
  }

  // ---- Comments ----
  const insertComment = db.prepare(
    `INSERT INTO comments (id, user_id, user_name, user_avatar, video_id, product_id, content, like_count)
     VALUES (@id, @user_id, @user_name, @user_avatar, @video_id, @product_id, @content, @like_count)`
  );
  const sampleComments = [
    { user_id: 'u1', user_name: '测试用户', content: '这个耳机真的绝了，降噪效果一级棒！', video_id: videoIds[0], like_count: 56 },
    { user_id: 'u1', user_name: '测试用户', content: '裙子好看！已经下单了期待收货～', video_id: videoIds[1], like_count: 32 },
    { user_id: 'u2', user_name: '小明数码', content: '扫地机器人解放双手神器不接受反驳', video_id: videoIds[2], like_count: 89 },
    { user_id: 'u3', user_name: '小红穿搭', content: '这个洁面泡沫敏感肌真的可以用！', video_id: videoIds[3], like_count: 44 },
    { user_id: 'u4', user_name: '阿杰户外', content: '上周带这个帐篷去露营，下雨完全没进水', video_id: videoIds[4], like_count: 67 },
    { user_id: 'u5', user_name: '数码控小王', content: '工学椅坐了三个月腰不疼了', video_id: videoIds[5], like_count: 123 },
    { user_id: 'u1', user_name: '测试用户', content: '鸡胸肉奥尔良口味最好吃！', video_id: videoIds[6], like_count: 28 },
    { user_id: 'u2', user_name: '小明数码', content: '磁吸充电宝真心方便，再也不用插线了', video_id: videoIds[7], like_count: 91 },
  ];
  for (const c of sampleComments) {
    insertComment.run({ id: uuid(), product_id: '', user_avatar: '', ...c });
  }

  const cartCount = (db.prepare('SELECT COUNT(*) as cnt FROM cart_items').get() as { cnt: number }).cnt;
  const orderCount = (db.prepare('SELECT COUNT(*) as cnt FROM orders').get() as { cnt: number }).cnt;

  // ---- Live Rooms ----
  // 给 4 个商家各自创建若干直播间，状态覆盖 preview / live / ended
  const allProductRows = db
    .prepare('SELECT id, video_id FROM products')
    .all() as Array<{ id: string; video_id: string }>;

  // 按 video_id 把商品聚合，方便按主播分配
  const productsByAuthor: Record<string, string[]> = { u2: [], u3: [], u4: [], u5: [] };
  for (let i = 0; i < allProductRows.length; i += 1) {
    const p = allProductRows[i];
    const ownerId = authorIds[i % authorIds.length];
    productsByAuthor[ownerId].push(p.id);
  }

  const liveRoomSeeds: Array<{
    author_id: string;
    author_name: string;
    title: string;
    cover_url: string;
    status: 'preview' | 'live' | 'ended';
    tags: string[];
    products: string[];
    video_url: string;
  }> = [
    {
      author_id: 'u2',
      author_name: '小明数码',
      title: '【直播中】数码新品发布｜限时秒杀',
      cover_url: 'https://picsum.photos/seed/live1/750/1334',
      status: 'live',
      tags: ['数码', '秒杀'],
      products: productsByAuthor.u2.slice(0, 4),
      video_url: 'http://192.168.50.174:3000/uploads/videos/video2.mp4',
    },
    {
      author_id: 'u2',
      author_name: '小明数码',
      title: '周末预告｜笔记本配件专场',
      cover_url: 'https://picsum.photos/seed/live2/750/1334',
      status: 'preview',
      tags: ['数码', '预告'],
      products: productsByAuthor.u2.slice(0, 3),
      video_url: 'http://192.168.50.174:3000/uploads/videos/video3.mp4',
    },
    {
      author_id: 'u3',
      author_name: '小红穿搭',
      title: '【直播中】春季穿搭专场｜全场五折',
      cover_url: 'https://picsum.photos/seed/live3/750/1334',
      status: 'live',
      tags: ['穿搭', '春季', '五折'],
      products: productsByAuthor.u3.slice(0, 4),
      video_url: 'http://192.168.50.174:3000/uploads/videos/butterfly.mp4',
    },
    {
      author_id: 'u4',
      author_name: '阿杰户外',
      title: '户外装备直播间｜露营帐篷开仓',
      cover_url: 'https://picsum.photos/seed/live4/750/1334',
      status: 'preview',
      tags: ['户外', '露营'],
      products: productsByAuthor.u4.slice(0, 3),
      video_url: 'http://192.168.50.174:3000/uploads/videos/video2.mp4',
    },
    {
      author_id: 'u5',
      author_name: '数码控小王',
      title: '上周回顾｜工学椅深度评测',
      cover_url: 'https://picsum.photos/seed/live5/750/1334',
      status: 'ended',
      tags: ['数码', '办公'],
      products: productsByAuthor.u5.slice(0, 2),
      video_url: 'http://192.168.50.174:3000/uploads/videos/video3.mp4',
    },
  ];

  const insertLiveRoom = db.prepare(`
    INSERT INTO live_rooms (
      id, title, cover_url, video_url,
      author_id, author_name, author_avatar,
      status, product_ids, current_product_id, tags,
      heat_count, like_count
    ) VALUES (
      @id, @title, @cover_url, @video_url,
      @author_id, @author_name, @author_avatar,
      @status, @product_ids, @current_product_id, @tags,
      @heat_count, @like_count
    )
  `);
  for (const r of liveRoomSeeds) {
    insertLiveRoom.run({
      id: uuid(),
      title: r.title,
      cover_url: r.cover_url,
      video_url: r.video_url,
      author_id: r.author_id,
      author_name: r.author_name,
      author_avatar: '',
      status: r.status,
      product_ids: JSON.stringify(r.products),
      current_product_id: r.status === 'live' && r.products.length > 0 ? r.products[0] : null,
      tags: JSON.stringify(r.tags),
      heat_count: r.status === 'live' ? 8000 + Math.floor(Math.random() * 12000) : 0,
      like_count: r.status === 'live' ? 1000 + Math.floor(Math.random() * 5000) : 0,
    });
  }

  // 用 SQL 表达式填充 started_at / ended_at（better-sqlite3 的命名参数无法绑定 SQL 函数）
  db.exec(`
    UPDATE live_rooms SET started_at = datetime('now', '-1 hour')   WHERE status = 'live'   AND started_at IS NULL;
    UPDATE live_rooms SET started_at = datetime('now', '-2 hours'),
                          ended_at   = datetime('now', '-10 minutes') WHERE status = 'ended' AND ended_at   IS NULL;
  `);

  const liveRoomCount = (db.prepare('SELECT COUNT(*) as cnt FROM live_rooms').get() as { cnt: number }).cnt;

  console.log('Seed completed!');
  console.log(`  - ${users.length} users`);
  console.log(`  - ${videos.length} videos`);
  console.log(`  - ${products.length} products`);
  console.log(`  - 2 coupons`);
  console.log(`  - ${sampleComments.length} comments`);
  console.log(`  - ${cartCount} cart items`);
  console.log(`  - ${orderCount} orders`);
  console.log(`  - ${liveRoomCount} live rooms`);
}

seed();
