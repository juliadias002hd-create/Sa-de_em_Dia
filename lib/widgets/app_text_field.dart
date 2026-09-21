import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Campo de texto padrão do app (com validação e olho de senha).
class AppTextField extends StatefulWidget {
  final TextEditingController controller;
  final String rotulo;
  final String? dica;
  final IconData? icone;
  final bool senha;
  final TextInputType? teclado;
  final TextInputAction? acaoTeclado;
  final String? Function(String?)? validador;
  final List<TextInputFormatter>? formatadores;
  final void Function(String)? aoEnviar;
  final void Function(String)? aoMudar;
  final VoidCallback? aoTocar;
  final bool somenteLeitura;
  final int linhasMaximas;
  final int? limiteCaracteres;
  final Widget? sufixo;
  final TextCapitalization capitalizacao;
  final Iterable<String>? autofill;
  final bool desativado;

  const AppTextField({
    super.key,
    required this.controller,
    required this.rotulo,
    this.dica,
    this.icone,
    this.senha = false,
    this.teclado,
    this.acaoTeclado,
    this.validador,
    this.formatadores,
    this.aoEnviar,
    this.aoMudar,
    this.aoTocar,
    this.somenteLeitura = false,
    this.linhasMaximas = 1,
    this.limiteCaracteres,
    this.sufixo,
    this.capitalizacao = TextCapitalization.none,
    this.autofill,
    this.desativado = false,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _oculta = true;

  @override
  Widget build(BuildContext context) {
    Widget? sufixo = widget.sufixo;

    if (widget.senha) {
      sufixo = IconButton(
        tooltip: _oculta ? 'Mostrar senha' : 'Ocultar senha',
        icon: Icon(
          _oculta ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
        onPressed: () => setState(() => _oculta = !_oculta),
      );
    }

    return TextFormField(
      controller: widget.controller,
      enabled: !widget.desativado,
      obscureText: widget.senha && _oculta,
      keyboardType: widget.teclado,
      textInputAction: widget.acaoTeclado,
      validator: widget.validador,
      inputFormatters: widget.formatadores,
      onFieldSubmitted: widget.aoEnviar,
      onChanged: widget.aoMudar,
      onTap: widget.aoTocar,
      readOnly: widget.somenteLeitura,
      maxLines: widget.senha ? 1 : widget.linhasMaximas,
      maxLength: widget.limiteCaracteres,
      textCapitalization: widget.capitalizacao,
      autofillHints: widget.autofill,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: widget.rotulo,
        hintText: widget.dica,
        counterText: '',
        prefixIcon: widget.icone == null ? null : Icon(widget.icone),
        suffixIcon: sufixo,
      ),
    );
  }
}
