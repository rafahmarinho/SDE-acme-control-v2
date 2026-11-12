Quero desenvolver esta aplicação, com aparência e funcionamento próximos de um produto real.

Use inglês como idioma padrão em todas as telas, mensagens, relatórios e dados de exemplo.

Use versões atuais e estáveis das tecnologias e Supabase para PostgreSQL, login por e-mail e

senha, arquivos e atualizações em tempo real. Quero as telas funcionando e os dados

persistidos, com integrações externas simuladas. Organize o projeto em telas, componentes,

serviços e acesso ao banco. Inclua login, recuperação de senha, perfil, configurações, busca,

filtros, estados de carregamento e mensagens de erro. Adapte a navegação aos perfis de

usuário.

O sistema industrial vai se chamar ACME Control e deve usar Flutter e Dart para web, Android

e iOS, com Material 3, Riverpod e go\_router. Use uma API TypeScript na Vercel para os

comandos e a simulação. Use pnpm na API TypeScript. Quero uma interface escura com um

diagrama de estação de tratamento de água, mostrando dois tanques, bombas, válvulas, nível,

pressão e vazão.

Crie páginas de plantas, visão do processo, equipamentos, alarmes, tendências, comandos,

setpoints, manutenção e passagem de turno. Permita ligar e desligar bombas, abrir e fechar

válvulas e alternar modos manual e automático, que mostre visualmente os fluxos da água (pode

usar algo 3d para isso). O processo deve responder aos comandos: os tanques enchem ou

esvaziam conforme o fluxo, e uma bomba não funciona se o tanque estiver vazio ou o

equipamento estiver em manutenção. Mostre o estado solicitado e o estado real. Tenha perfis

de operador, engenheiro, supervisor e manutenção, com propostas de alteração de setpoints

analisadas pelo supervisor. No mobile, adapte o diagrama e use abas para planta, alarmes,

ativos e outras opções.

Prepare dados de demonstração com duas plantas industriais. Inclua uma área para escolher

cenários, avançar a simulação, consultar eventos e reiniciar os dados. Os resultados devem

aparecer nas telas e continuar salvos após recarregar a aplicação. As versões web e mobile

devem compartilhar o mesmo projeto Supabase. No celular, adapte os formulários ao toque,

pause as atualizações em segundo plano e mostre os últimos dados como leitura offline. Retome

as atualizações quando a conexão voltar; ações de controle exigem conexão. Entregue o código

completo, configuração do banco, dados iniciais, exemplos de variáveis de ambiente e um

README com os passos para rodar e publicar a versão web e a API na Vercel. Inclua as versões

Android e iOS e instruções para gerar os pacotes nativos. Confira os fluxos principais,

mantenha a implementação objetiva e conclua as páginas e ações descritas.

