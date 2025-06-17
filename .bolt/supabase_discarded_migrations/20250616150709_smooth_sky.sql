/*
  # Criação da tabela de cache do sistema

  1. Nova Tabela
    - `system_cache` - Armazena resultados em cache para otimização de performance
  
  2. Índices
    - Índices para melhorar a performance de consultas de cache
  
  3. Funções
    - Função para limpeza automática de cache expirado
*/

-- Criar tabela de cache do sistema se não existir
CREATE TABLE IF NOT EXISTS system_cache (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key text NOT NULL UNIQUE,
  value jsonb NOT NULL,
  created_at timestamptz DEFAULT now(),
  expires_at timestamptz DEFAULT (now() + interval '24 hours')
);

-- Habilitar RLS para a tabela de cache
ALTER TABLE system_cache ENABLE ROW LEVEL SECURITY;

-- Criar política para administradores
CREATE POLICY "Admins can manage system cache"
  ON system_cache
  FOR ALL
  TO public
  USING (is_admin(auth.uid()));

-- Criar índices para melhorar performance
CREATE INDEX IF NOT EXISTS idx_system_cache_key ON system_cache(key);
CREATE INDEX IF NOT EXISTS idx_system_cache_expires_at ON system_cache(expires_at);

-- Função para limpar cache expirado
CREATE OR REPLACE FUNCTION clean_expired_cache()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  DELETE FROM system_cache
  WHERE expires_at < now();
END;
$$;

-- Conceder permissões para a função
GRANT EXECUTE ON FUNCTION clean_expired_cache TO authenticated;