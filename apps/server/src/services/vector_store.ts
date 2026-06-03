/**
 * 向量存储接口
 * 当前使用 DummyVectorStore：不做向量检索，直接返回全部文档
 * 后续可替换为 MemoryVectorStore、Chroma、Pinecone 等
 */
import type { ProductDoc } from './product_docs.js';
import { getAllProductDocs } from './product_docs.js';

/**
 * 向量存储接口定义
 * 后续扩展时实现此接口即可
 */
export interface IVectorStore {
  /** 根据查询文本搜索最相关的商品文档 */
  search(query: string, topK?: number): Promise<ProductDoc[]>;
  /** 重新构建索引（新增/更新商品时调用） */
  rebuild(docs: ProductDoc[]): Promise<void>;
}

/**
 * 虚拟向量存储实现
 * 不做向量检索，直接返回所有文档
 * 适用于测试阶段或文档量较少的场景
 */
export class DummyVectorStore implements IVectorStore {
  private docs: ProductDoc[] = [];

  constructor() {
    this.docs = getAllProductDocs();
  }

  async search(_query: string, _topK?: number): Promise<ProductDoc[]> {
    // 当前：返回所有文档
    // 后续：使用 embedding 进行向量相似度搜索
    return this.docs;
  }

  async rebuild(docs: ProductDoc[]): Promise<void> {
    this.docs = docs;
  }
}

/**
 * 单例获取向量存储实例
 * 后续可改为根据配置返回不同实现
 */
let _instance: IVectorStore | null = null;

export function getVectorStore(): IVectorStore {
  if (!_instance) {
    _instance = new DummyVectorStore();
  }
  return _instance;
}
