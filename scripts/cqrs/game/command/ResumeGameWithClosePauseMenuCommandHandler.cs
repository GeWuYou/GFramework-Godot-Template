using GFrameworkGodotTemplate.scripts.cqrs.pause_menu.command;

namespace GFrameworkGodotTemplate.scripts.cqrs.game.command;

/// <summary>
///     恢复游戏并关闭暂停菜单命令处理器
/// </summary>
public class ResumeGameWithClosePauseMenuCommandHandler : AbstractCommandHandler<ResumeGameWithClosePauseMenuCommand>
{
    public override async ValueTask<Unit> Handle(ResumeGameWithClosePauseMenuCommand command,
        CancellationToken cancellationToken)
    {
        await this.SendAsync(new ClosePauseMenuCommand(command.Input), cancellationToken).ConfigureAwait(true);
        await this.SendAsync(new ResumeGameCommand(), cancellationToken).ConfigureAwait(true);

        return Unit.Value;
    }
}
