# Autenticação própria com JWT, não Basic Auth do nginx

O acesso é protegido por tela de login e token JWT de 30 dias (necessário para uso offline), emitido pelo backend contra uma tabela `usuarios` com senha em hash. Há um único papel (administrador); o admin inicial vem de variáveis de ambiente. O Basic Auth do nginx sai deste caminho. A tabela já nasce pronta para um CRUD de usuários futuro.
